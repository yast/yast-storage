// -*- C++ -*-
// Maintainer: schwab@suse.de

#ifndef _PART_INFO_DEFS_H
#define _PART_INFO_DEFS_H

#include <iostream>
#include <string>

using std::ostream;

#define PART_ID_LINUX_NATIVE 0x83
#define PART_ID_LINUX_SWAP   0x82
#define PART_ID_DOS          0x06
#define PART_ID_UNUSED       0x00
#define LVM_PART_ID          0x8E

#define LVM_MAJOR_NUMBER       58

enum PartitionType
{
  PAR_TYPE_LINUX,
  PAR_TYPE_SWAP,
  PAR_TYPE_DOS,
  PAR_TYPE_HPFS,
  PAR_TYPE_EXTENDED,
  PAR_TYPE_PRIMARY,
  PAR_TYPE_LOGICAL,
  PAR_TYPE_LVM_PV,
  PAR_TYPE_RAID_PV,
  PAR_TYPE_UNUSED,
  PAR_TYPE_OTHER     // Should be last value
};

enum ErrorBehaviour
{
  EB_DEFAULT,
  EB_REMOUNT_RO,
  EB_CONTINUE,
  EB_PANIC
};

inline ostream& operator<<(ostream& Str, const PartitionType& Obj) { return Str << (int)Obj; }


enum FilesystemType
{
  FS_TYPE_EXT2,
  FS_TYPE_XIAFS,
  FS_TYPE_DOS,
  FS_TYPE_UMSDOS,
  FS_TYPE_HPFS,
  FS_TYPE_ISO9660,
  FS_TYPE_MINIX,
  FS_TYPE_NFS,
  FS_TYPE_VFAT,
  FS_TYPE_SWAP,
  FS_TYPE_REISER,
  FS_TYPE_HFS,
  FS_TYPE_ANY,
  FS_TYPE_UNUSED,
  FS_TYPE_OTHER       // Should be last value
};

inline ostream& operator<<(ostream& Str, const FilesystemType& Obj) { return Str << (int)Obj; }


enum FormatType
{
  FORMAT_NO,
  FORMAT_YES,
  FORMAT_CHECK
};

inline ostream& operator<<(ostream& Str, const FormatType& Obj ) { return Str << (int)Obj; }


struct PartInfo
{
  PartInfo() 
  {
    PType_e = PAR_TYPE_LINUX;
    Filesys_e = FS_TYPE_EXT2;
    Format_e = FORMAT_NO;
    Error_e = EB_DEFAULT,
      Id_i = Num_i = Start_i = End_i = Blocks_i = SpaceInK_i = 0;
    SpaceTotal_i = 0;
    InodeDens_i = ReservedBlock_i = ReservedBlockPC_i = -1;
    BlockSize_i = MaxMountCount_i = FragmentSize_i = -1;
    Changed_b = HasFstab_b = NonStandard_b = HideInList_b = false;
  }
  PartitionType PType_e;
  FilesystemType Filesys_e;
  FormatType Format_e;
  ErrorBehaviour Error_e;
  string Device_C;
  string Mount_C;
  string Info_C;
  string FstabLine_C;
  unsigned Id_i;
  unsigned Num_i;
  unsigned Start_i;
  unsigned End_i;
  unsigned Blocks_i;
  unsigned SpaceInK_i;
  unsigned SpaceTotal_i;
  int InodeDens_i;
  int MaxMountCount_i;
  int BlockSize_i;
  int ReservedBlockPC_i;
  int ReservedBlock_i;
  int FragmentSize_i;
  bool Changed_b;
  bool HasFstab_b;
  bool NonStandard_b;
  bool HideInList_b;
  bool operator ==(const PartInfo& Rhs_rv)
  {
    return (Start_i == Rhs_rv.Start_i &&
	    End_i == Rhs_rv.End_i &&
	    PType_e == Rhs_rv.PType_e &&
	    Filesys_e == Rhs_rv.Filesys_e &&
	    Format_e == Rhs_rv.Format_e &&
	    Error_e == Rhs_rv.Error_e &&
	    Device_C == Rhs_rv.Device_C &&
	    Mount_C == Rhs_rv.Mount_C &&
	    Info_C == Rhs_rv.Info_C &&
	    FstabLine_C == Rhs_rv.FstabLine_C &&
	    Id_i == Rhs_rv.Id_i &&
	    Num_i == Rhs_rv.Num_i &&
	    Blocks_i == Rhs_rv.Blocks_i &&
	    InodeDens_i == Rhs_rv.InodeDens_i &&
	    SpaceInK_i == Rhs_rv.SpaceInK_i &&
	    SpaceTotal_i == Rhs_rv.SpaceTotal_i &&
	    MaxMountCount_i == Rhs_rv.MaxMountCount_i &&
	    BlockSize_i == Rhs_rv.BlockSize_i &&
	    ReservedBlockPC_i == Rhs_rv.ReservedBlockPC_i &&
	    ReservedBlock_i == Rhs_rv.ReservedBlock_i &&
	    FragmentSize_i == Rhs_rv.FragmentSize_i &&
	    Changed_b == Rhs_rv.Changed_b &&
	    HasFstab_b == Rhs_rv.HasFstab_b &&
	    HideInList_b == Rhs_rv.HideInList_b &&
	    NonStandard_b == Rhs_rv.NonStandard_b);
  }
};

#define IsSwap( A ) ((A).PType_e==PAR_TYPE_SWAP||(A).Filesys_e==FS_TYPE_SWAP)
#define IsLinuxPart( A ) ((A).PType_e==PAR_TYPE_LINUX || \
                          (A).PType_e==PAR_TYPE_RAID_PV || \
                          (A).PType_e==PAR_TYPE_LVM_PV)

#define PartInfoEQ( A, B ) ((A)==(B))

#define REGEX_NAME_DISK "[esh]d[a-z]|dasd[a-z]+\\|i2o/hd[a-z]\\|rd/c[0-9]+d[0-9]+\\|ida/c[0-9]+d[0-9]+\\|cciss/c[0-9]+d[0-9]+"

#define REGEX_DEVICE_NAME "\\([esh]d[a-z]\\|dasd[a-z]+\\|md\\|i2o/hd[a-z]\\|rd/c[0-9]+d[0-9]+p\\|ida/c[0-9]+d[0-9]+p\\|cciss/c[0-9]+d[0-9]+p\\)[0-9]+"
#define REGEX_DEVICE_PARTITION "/dev/" REGEX_DEVICE_NAME

#endif
