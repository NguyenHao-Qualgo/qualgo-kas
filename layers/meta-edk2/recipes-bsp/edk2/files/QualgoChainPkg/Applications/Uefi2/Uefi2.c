/*
    Uefi2.c - Second-stage UEFI loader (kernel + optional initrd via LINUX_EFI_INITRD_MEDIA_GUID)

    Chain:
      Firmware -> uefi1.efi (decrypts uefi2) -> uefi2.efi -> Linux kernel Image

    This loader does the following:
      1) Enumerates all Simple File System handles and finds the one that contains \boot\Image.
      2) Loads the Linux kernel Image from \boot\Image into memory.
      3) Optionally loads initrd from \boot\initrd into memory.
      4) If initrd is present, exposes it via EFI_LOAD_FILE2 + LINUX_EFI_INITRD_MEDIA_GUID.
      5) Constructs a MemMap Device Path for the in-memory kernel.
      6) Calls LoadImage()/StartImage() for the kernel EFI stub.
      7) Sets the kernel command line via LOADED_IMAGE.LoadOptions.

    Policy:
      - If BOOT=PXE is present in LoadOptions (passed from uefi1), use NFS cmdline and SKIP initrd.
      - Otherwise, use local cmdline and load initrd from local FS.
*/

#include <Uefi.h>

#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DevicePathLib.h>
#include <Library/BaseLib.h>

#include <Protocol/LoadedImage.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/DevicePath.h>
#include <Protocol/LoadFile2.h>

#include <Guid/FileInfo.h>
#include <Guid/LinuxEfiInitrdMedia.h>

/* Paths for kernel Image and initrd on the root filesystem */
#define KERNEL_PATH   L"\\boot\\Image"
#define INITRD_PATH   L"\\boot\\initrd"

/* BOOT mode tags (passed from uefi1 via LoadOptions) */
#define BOOTOPT_PXE   L"BOOT=PXE"
#define BOOTOPT_FS    L"BOOT=FS"

/* NFS server/export (adjust if needed) */
#define NFS_SERVER_IP   L"192.168.42.1"
#define NFS_ROOT_EXPORT L"/volume1/nfs_root"

/* Logging helpers */
#define LOG_PREFIX L"[uefi2] "
#define LOGI(fmt, ...)  Print(LOG_PREFIX fmt L"\n", ##__VA_ARGS__)
#define LOGW(fmt, ...)  Print(LOG_PREFIX L"WARN: "  fmt L"\n", ##__VA_ARGS__)
#define LOGE(fmt, ...)  Print(LOG_PREFIX L"ERROR: " fmt L"\n", ##__VA_ARGS__)

#pragma pack(push, 1)
typedef struct {
    MEMMAP_DEVICE_PATH       MemMap;
    EFI_DEVICE_PATH_PROTOCOL End;
} MEMMAP_DEVICE_PATH_WITH_END;
#pragma pack(pop)

/* Device path used to expose initrd via LINUX_EFI_INITRD_MEDIA_GUID */
typedef struct {
    VENDOR_DEVICE_PATH       Vendor;
    EFI_DEVICE_PATH_PROTOCOL End;
} LINUX_INITRD_DEVICE_PATH;

static LINUX_INITRD_DEVICE_PATH mInitrdDevPath = {
    {
        {
            MEDIA_DEVICE_PATH,
            MEDIA_VENDOR_DP,
            { sizeof(VENDOR_DEVICE_PATH), 0 }
        },
        LINUX_EFI_INITRD_MEDIA_GUID
    },
    {
        END_DEVICE_PATH_TYPE,
        END_ENTIRE_DEVICE_PATH_SUBTYPE,
        { sizeof(EFI_DEVICE_PATH_PROTOCOL), 0 }
    }
};

/* Local-root cmdline (NVMe example) */
static CONST CHAR16 KernelCmdline[] =
    L"root=/dev/nvme0n1p1 rw rootwait rootdelay=10 rootfstype=ext4 "
    L"mminit_loglevel=4 "
    L"console=ttyTCU0,115200 "
    L"firmware_class.path=/etc/firmware "
    L"fbcon=map:0 net.ifnames=0 nospectre_bhb "
    L"video=efifb:off console=tty0";

/* NFS-root cmdline (PXE/NFS). Note: we intentionally skip initrd for NFS-root to avoid switch_root issues. */
static CONST CHAR16 KernelCmdlineNfs[] =
    L"ip=dhcp "
    L"root=/dev/nfs rw "
    L"nfsroot=" NFS_SERVER_IP L":" NFS_ROOT_EXPORT L",vers=4,tcp "
    L"console=ttyTCU0,115200n8 console=tty0 "
    L"firmware_class.path=/etc/firmware "
    L"net.ifnames=0 "
    L"loglevel=7";

/* Context for EFI_LOAD_FILE2 protocol (initrd provider) */
typedef struct {
    EFI_LOAD_FILE2_PROTOCOL Proto;
    VOID                   *InitrdBuffer;
    UINTN                   InitrdSize;
} INITRD_LOADFILE2_CTX;

static INITRD_LOADFILE2_CTX mInitrdLf2;

/*
  LoadFile2 callback: Linux EFI stub calls this to receive the initrd.
*/
static EFI_STATUS EFIAPI
InitrdLoadFile(
    IN EFI_LOAD_FILE2_PROTOCOL  *This,
    IN EFI_DEVICE_PATH_PROTOCOL *FilePath   OPTIONAL,
    IN BOOLEAN                   BootPolicy,
    IN OUT UINTN                *BufferSize,
    IN VOID                     *Buffer      OPTIONAL
    )
{
    INITRD_LOADFILE2_CTX *Ctx = &mInitrdLf2;

    if (BufferSize == NULL) {
        return EFI_INVALID_PARAMETER;
    }

    if (Ctx->InitrdBuffer == NULL || Ctx->InitrdSize == 0) {
        return EFI_NOT_FOUND;
    }

    if (Buffer == NULL || *BufferSize < Ctx->InitrdSize) {
        *BufferSize = Ctx->InitrdSize;
        return EFI_BUFFER_TOO_SMALL;
    }

    CopyMem(Buffer, Ctx->InitrdBuffer, Ctx->InitrdSize);
    *BufferSize = Ctx->InitrdSize;

    return EFI_SUCCESS;
}

/*
  Load an entire file into an allocated buffer from the given Root.
*/
static EFI_STATUS
LoadFileToBuffer(
    IN  EFI_FILE_PROTOCOL  *Root,
    IN  CONST CHAR16       *Path,
    OUT VOID               **Buffer,
    OUT UINTN              *BufferSize
    )
{
    EFI_STATUS         Status;
    EFI_FILE_PROTOCOL *File;
    EFI_FILE_INFO     *FileInfo = NULL;
    UINTN              InfoSize = 0;

    if (Buffer == NULL || BufferSize == NULL || Root == NULL || Path == NULL) {
        return EFI_INVALID_PARAMETER;
    }

    *Buffer     = NULL;
    *BufferSize = 0;

    Status = Root->Open(
        Root,
        &File,
        (CHAR16 *)Path,
        EFI_FILE_MODE_READ,
        0
    );
    if (EFI_ERROR(Status)) {
        LOGW(L"Open(%s) failed: %r", Path, Status);
        return Status;
    }

    Status = File->GetInfo(File, &gEfiFileInfoGuid, &InfoSize, NULL);
    if (Status != EFI_BUFFER_TOO_SMALL) {
        LOGE(L"GetInfo(size) failed for %s: %r", Path, Status);
        File->Close(File);
        return Status;
    }

    Status = gBS->AllocatePool(EfiLoaderData, InfoSize, (VOID **)&FileInfo);
    if (EFI_ERROR(Status)) {
        LOGE(L"AllocatePool(FileInfo) failed: %r", Status);
        File->Close(File);
        return Status;
    }

    Status = File->GetInfo(File, &gEfiFileInfoGuid, &InfoSize, FileInfo);
    if (EFI_ERROR(Status)) {
        LOGE(L"GetInfo(info) failed for %s: %r", Path, Status);
        gBS->FreePool(FileInfo);
        File->Close(File);
        return Status;
    }

    *BufferSize = (UINTN)FileInfo->FileSize;
    gBS->FreePool(FileInfo);

    Status = gBS->AllocatePool(EfiLoaderData, *BufferSize, Buffer);
    if (EFI_ERROR(Status)) {
        LOGE(L"AllocatePool(file buffer) failed for %s: %r", Path, Status);
        File->Close(File);
        return Status;
    }

    Status = File->Read(File, BufferSize, *Buffer);
    File->Close(File);

    if (EFI_ERROR(Status)) {
        LOGE(L"Read(%s) failed: %r", Path, Status);
        gBS->FreePool(*Buffer);
        *Buffer     = NULL;
        *BufferSize = 0;
        return Status;
    }

    LOGI(L"Loaded %s at 0x%lx size=%u", Path, (UINT64)(UINTN)(*Buffer), (UINT32)(*BufferSize));
    return EFI_SUCCESS;
}

/*
  Enumerate all SimpleFS handles and find one that contains KERNEL_PATH.
  On success, RootOut is an open EFI_FILE_PROTOCOL for the root of that filesystem.
*/
static EFI_STATUS
FindBootFileSystem(
    OUT EFI_FILE_PROTOCOL **RootOut
    )
{
    EFI_STATUS                       Status;
    UINTN                            HandleCount = 0;
    EFI_HANDLE                      *HandleBuffer = NULL;
    UINTN                            Index;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *Sfsp;
    EFI_FILE_PROTOCOL               *Root;
    EFI_FILE_PROTOCOL               *TestFile;

    if (RootOut == NULL) {
        return EFI_INVALID_PARAMETER;
    }
    *RootOut = NULL;

    Status = gBS->LocateHandleBuffer(
        ByProtocol,
        &gEfiSimpleFileSystemProtocolGuid,
        NULL,
        &HandleCount,
        &HandleBuffer
    );
    if (EFI_ERROR(Status)) {
        LOGE(L"LocateHandleBuffer(SimpleFS) failed: %r", Status);
        return Status;
    }

    LOGI(L"Found %u SimpleFS handles", (UINT32)HandleCount);

    for (Index = 0; Index < HandleCount; Index++) {
        EFI_DEVICE_PATH_PROTOCOL *Dp = NULL;

        Status = gBS->HandleProtocol(
            HandleBuffer[Index],
            &gEfiDevicePathProtocolGuid,
            (VOID**)&Dp
        );
        if (!EFI_ERROR(Status) && Dp != NULL) {
            CHAR16 *Txt = ConvertDevicePathToText(Dp, FALSE, FALSE);
            if (Txt != NULL) {
                LOGI(L"FS[%u] DP: %s", (UINT32)Index, Txt);
                gBS->FreePool(Txt);
            }
        }

        Status = gBS->HandleProtocol(
            HandleBuffer[Index],
            &gEfiSimpleFileSystemProtocolGuid,
            (VOID**)&Sfsp
        );
        if (EFI_ERROR(Status) || Sfsp == NULL) {
            LOGW(L"HandleProtocol(SimpleFS) failed for FS[%u]: %r", (UINT32)Index, Status);
            continue;
        }

        Status = Sfsp->OpenVolume(Sfsp, &Root);
        if (EFI_ERROR(Status) || Root == NULL) {
            LOGW(L"OpenVolume failed for FS[%u]: %r", (UINT32)Index, Status);
            continue;
        }

        Status = Root->Open(
            Root,
            &TestFile,
            KERNEL_PATH,
            EFI_FILE_MODE_READ,
            0
        );

        if (!EFI_ERROR(Status)) {
            TestFile->Close(TestFile);
            *RootOut = Root;

            LOGI(L"Found %s on filesystem handle #%u", KERNEL_PATH, (UINT32)Index);
            gBS->FreePool(HandleBuffer);
            return EFI_SUCCESS;
        }

        LOGI(L"%s not found on FS[%u]: %r", KERNEL_PATH, (UINT32)Index, Status);
        // Root handle remains open; close it to avoid handle leaks
        Root->Close(Root);
    }

    gBS->FreePool(HandleBuffer);
    LOGE(L"Could not find %s on any filesystem", KERNEL_PATH);
    return EFI_NOT_FOUND;
}

STATIC
BOOLEAN
IsNetworkBoot(IN EFI_HANDLE ImageHandle)
{
    EFI_LOADED_IMAGE_PROTOCOL *Li = NULL;
    EFI_STATUS Status;

    Status = gBS->HandleProtocol(ImageHandle, &gEfiLoadedImageProtocolGuid, (VOID**)&Li);
    if (EFI_ERROR(Status) || Li == NULL) {
        LOGW(L"HandleProtocol(LoadedImage) failed: %r", Status);
        return FALSE;
    }

    if (Li->LoadOptions == NULL || Li->LoadOptionsSize < sizeof(CHAR16)) {
        LOGI(L"No LoadOptions from uefi1 (assume Local)");
        return FALSE;
    }

    CONST CHAR16 *Opts = (CONST CHAR16*)Li->LoadOptions;

    LOGI(L"Received LoadOptionsSize=%u", (UINT32)Li->LoadOptionsSize);
    LOGI(L"Received LoadOptions: %s", Opts);

    return (StrStr(Opts, BOOTOPT_PXE) != NULL);
}

static EFI_STATUS
LoadAndStartKernelFromAnyFs(
    IN EFI_HANDLE     ImageHandle,
    IN CONST CHAR16  *Cmdline,
    IN BOOLEAN        UseInitrd
    )
{
    EFI_STATUS                   Status;
    EFI_FILE_PROTOCOL           *Root          = NULL;
    VOID                        *KernelBuffer  = NULL;
    UINTN                        KernelSize    = 0;
    VOID                        *InitrdBuffer  = NULL;
    UINTN                        InitrdSize    = 0;
    MEMMAP_DEVICE_PATH_WITH_END  KernelDp;
    EFI_HANDLE                   KernelHandle  = NULL;
    EFI_LOADED_IMAGE_PROTOCOL   *KernelLoadedImage = NULL;
    EFI_HANDLE                   InitrdHandle  = NULL;

    LOGI(L"LoadAndStartKernelFromAnyFs() entered");
    LOGI(L"Searching for filesystem containing %s", KERNEL_PATH);

    Status = FindBootFileSystem(&Root);
    if (EFI_ERROR(Status) || Root == NULL) {
        LOGE(L"FindBootFileSystem() failed: %r", Status);
        return Status;
    }

    /* Load kernel */
    Status = LoadFileToBuffer(Root, KERNEL_PATH, &KernelBuffer, &KernelSize);
    if (EFI_ERROR(Status)) {
        LOGE(L"Failed to load kernel %s: %r", KERNEL_PATH, Status);
        Root->Close(Root);
        return Status;
    }

    LOGI(L"Kernel loaded at 0x%lx size=%u", (UINT64)(UINTN)KernelBuffer, (UINT32)KernelSize);

    /* Load initrd optionally */
    if (UseInitrd) {
        Status = LoadFileToBuffer(Root, INITRD_PATH, &InitrdBuffer, &InitrdSize);
        if (EFI_ERROR(Status)) {
            LOGW(L"Initrd %s not loaded: %r (booting without initrd)", INITRD_PATH, Status);
            InitrdBuffer = NULL;
            InitrdSize   = 0;
        } else {
            LOGI(L"Initrd loaded at 0x%lx size=%u", (UINT64)(UINTN)InitrdBuffer, (UINT32)InitrdSize);
        }
    } else {
        LOGI(L"Skipping initrd (network/NFS boot)");
    }

    /* Close Root now (we already loaded files into RAM) */
    Root->Close(Root);

    /* Register initrd (only if present) */
    if (InitrdSize > 0) {
        ZeroMem(&mInitrdLf2, sizeof(mInitrdLf2));
        mInitrdLf2.Proto.LoadFile = InitrdLoadFile;
        mInitrdLf2.InitrdBuffer   = InitrdBuffer;
        mInitrdLf2.InitrdSize     = InitrdSize;

        Status = gBS->InstallMultipleProtocolInterfaces(
            &InitrdHandle,
            &gEfiDevicePathProtocolGuid, (VOID *)&mInitrdDevPath,
            &gEfiLoadFile2ProtocolGuid,  (VOID *)&mInitrdLf2.Proto,
            NULL
        );
        if (EFI_ERROR(Status)) {
            LOGE(L"InstallMultipleProtocolInterfaces(initrd) failed: %r", Status);
            // Cleanup kernel buffer before returning
            gBS->FreePool(KernelBuffer);
            if (InitrdBuffer) gBS->FreePool(InitrdBuffer);
            return Status;
        }

        LOGI(L"Initrd registered via LINUX_EFI_INITRD_MEDIA_GUID (size=%u)", (UINT32)InitrdSize);
    }

    /* Build MemMap DP for kernel image in memory */
    ZeroMem(&KernelDp, sizeof(KernelDp));

    KernelDp.MemMap.Header.Type    = HARDWARE_DEVICE_PATH;
    KernelDp.MemMap.Header.SubType = HW_MEMMAP_DP;

    {
        UINT16 MemMapLength = (UINT16)sizeof(MEMMAP_DEVICE_PATH);
        KernelDp.MemMap.Header.Length[0] = (UINT8)(MemMapLength & 0xFF);
        KernelDp.MemMap.Header.Length[1] = (UINT8)((MemMapLength >> 8) & 0xFF);
    }

    KernelDp.MemMap.MemoryType      = EfiLoaderData;
    KernelDp.MemMap.StartingAddress = (EFI_PHYSICAL_ADDRESS)(UINTN)KernelBuffer;
    KernelDp.MemMap.EndingAddress   = KernelDp.MemMap.StartingAddress + (KernelSize - 1);

    KernelDp.End.Type      = END_DEVICE_PATH_TYPE;
    KernelDp.End.SubType   = END_ENTIRE_DEVICE_PATH_SUBTYPE;
    KernelDp.End.Length[0] = (UINT8)sizeof(EFI_DEVICE_PATH_PROTOCOL);
    KernelDp.End.Length[1] = 0;

    /* Load kernel as EFI image (Linux EFI stub) */
    Status = gBS->LoadImage(
        FALSE,
        ImageHandle,
        (EFI_DEVICE_PATH_PROTOCOL *)&KernelDp,
        KernelBuffer,
        KernelSize,
        &KernelHandle
    );
    if (EFI_ERROR(Status)) {
        LOGE(L"LoadImage(kernel via MemMap DP) failed: %r", Status);
        gBS->FreePool(KernelBuffer);
        if (InitrdBuffer) gBS->FreePool(InitrdBuffer);
        return Status;
    }

    /* Set kernel cmdline */
    Status = gBS->HandleProtocol(
        KernelHandle,
        &gEfiLoadedImageProtocolGuid,
        (VOID**)&KernelLoadedImage
    );
    if (EFI_ERROR(Status) || KernelLoadedImage == NULL) {
        LOGE(L"HandleProtocol(LoadedImage for kernel) failed: %r", Status);
        return Status;
    }

    KernelLoadedImage->LoadOptions     = (VOID *)Cmdline;
    KernelLoadedImage->LoadOptionsSize = (UINT32)((StrLen(Cmdline) + 1) * sizeof(CHAR16));

    LOGI(L"Using kernel cmdline: %s", Cmdline);
    LOGI(L"Starting kernel Image...");

    /* Start kernel */
    Status = gBS->StartImage(KernelHandle, NULL, NULL);

    LOGW(L"StartImage(kernel) returned: %r", Status);
    return Status;
}

EFI_STATUS EFIAPI
UefiMain(
    IN EFI_HANDLE        ImageHandle,
    IN EFI_SYSTEM_TABLE  *SystemTable
    )
{
    EFI_STATUS Status;
    BOOLEAN    NetBoot;
    CONST CHAR16 *Cmdline;
    BOOLEAN    UseInitrd;

    LOGI(L"UefiMain() start");

    NetBoot = IsNetworkBoot(ImageHandle);
    LOGI(L"Boot source: %s", NetBoot ? L"PXE/Network" : L"Local FS");

    Cmdline   = NetBoot ? KernelCmdlineNfs : KernelCmdline;
    UseInitrd = NetBoot ? FALSE            : TRUE;

    LOGI(L"UseInitrd=%d", UseInitrd ? 1 : 0);
    LOGI(L"Selected cmdline: %s", Cmdline);

    Status = LoadAndStartKernelFromAnyFs(ImageHandle, Cmdline, UseInitrd);

    LOGI(L"UefiMain() exit: %r", Status);
    return Status;
}
