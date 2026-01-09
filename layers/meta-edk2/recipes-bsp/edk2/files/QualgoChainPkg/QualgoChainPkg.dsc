[Defines]
  PLATFORM_NAME           = QualgoChainPkg
  PLATFORM_GUID           = 22222222-2222-2222-2222-222222222222
  PLATFORM_VERSION        = 1.0
  DSC_SPECIFICATION       = 0x0001001C
  OUTPUT_DIRECTORY        = Build/QualgoChainPkg
  SUPPORTED_ARCHITECTURES = AARCH64
  BUILD_TARGETS           = DEBUG|RELEASE

[Packages]
  QualgoChainPkg/QualgoChainPkg.dec

[LibraryClasses]
  UefiApplicationEntryPoint      | MdePkg/Library/UefiApplicationEntryPoint/UefiApplicationEntryPoint.inf
  UefiLib                        | MdePkg/Library/UefiLib/UefiLib.inf
  UefiBootServicesTableLib       | MdePkg/Library/UefiBootServicesTableLib/UefiBootServicesTableLib.inf
  UefiRuntimeServicesTableLib    | MdePkg/Library/UefiRuntimeServicesTableLib/UefiRuntimeServicesTableLib.inf
  BaseLib                        | MdePkg/Library/BaseLib/BaseLib.inf
  BaseMemoryLib                  | MdePkg/Library/BaseMemoryLib/BaseMemoryLib.inf
  MemoryAllocationLib            | MdePkg/Library/UefiMemoryAllocationLib/UefiMemoryAllocationLib.inf
  PrintLib                       | MdePkg/Library/BasePrintLib/BasePrintLib.inf
  DevicePathLib                  | MdePkg/Library/UefiDevicePathLib/UefiDevicePathLib.inf
  FileHandleLib                  | MdePkg/Library/UefiFileHandleLib/UefiFileHandleLib.inf
  ShellCEntryLib                 | ShellPkg/Library/UefiShellCEntryLib/UefiShellCEntryLib.inf
  ShellLib                       | ShellPkg/Library/UefiShellLib/UefiShellLib.inf
  DebugLib                       | MdePkg/Library/UefiDebugLibConOut/UefiDebugLibConOut.inf
  PcdLib                         | MdePkg/Library/BasePcdLibNull/BasePcdLibNull.inf
  HiiLib                         | MdeModulePkg/Library/UefiHiiLib/UefiHiiLib.inf
  UefiHiiServicesLib             | MdeModulePkg/Library/UefiHiiServicesLib/UefiHiiServicesLib.inf
  SortLib                        | MdeModulePkg/Library/UefiSortLib/UefiSortLib.inf
  DebugPrintErrorLevelLib        | MdePkg/Library/BaseDebugPrintErrorLevelLib/BaseDebugPrintErrorLevelLib.inf
  StackCheckLib                  | MdePkg/Library/StackCheckLibNull/StackCheckLibNull.inf
  CompilerIntrinsicsLib          | MdePkg/Library/CompilerIntrinsicsLib/CompilerIntrinsicsLib.inf
  IntrinsicLib                   | CryptoPkg/Library/IntrinsicLib/IntrinsicLib.inf
  SynchronizationLib             | MdePkg/Library/BaseSynchronizationLib/BaseSynchronizationLib.inf
  TimerLib                       | MdePkg/Library/BaseTimerLibNullTemplate/BaseTimerLibNullTemplate.inf
  RngLib                         | MdePkg/Library/BaseRngLib/BaseRngLib.inf
  BaseCryptLib                   | CryptoPkg/Library/BaseCryptLib/BaseCryptLib.inf
  OpensslLib                     | CryptoPkg/Library/OpensslLib/OpensslLibCrypto.inf

[BuildOptions]
  GCC:*_GCC5_AARCH64_CC_FLAGS = -nostdinc -DOPENSSL_SYS_UEFI -DOPENSSL_NO_STDIO -DSIXTY_FOUR_BIT -D__STDC_NO_ATOMICS__ -DOPENSSL_NO_TSAN -I$(WORKSPACE)/CryptoPkg/Library/Include -I$(WORKSPACE)/CryptoPkg/Library/OpensslLib/OpensslGen/include -I$(WORKSPACE)/CryptoPkg/Library/OpensslLib/openssl/include

[Components]
  QualgoChainPkg/Applications/Uefi1/Uefi1.inf
  QualgoChainPkg/Applications/Uefi2/Uefi2.inf
  QualgoChainPkg/Applications/AutoEnroll/AutoEnroll.inf

