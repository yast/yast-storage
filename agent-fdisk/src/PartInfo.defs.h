// -*- C++ -*-
// Maintainer: fehr@suse.de

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
    Blocks_l = Id_i = Num_i = Start_i = End_i = 0;
    Boot_b = false;
  }
  PartitionType PType_e;
  string Device_C;
  string Info_C;
  string RealStart_C;
  unsigned Id_i;
  unsigned Num_i;
  unsigned Start_i;
  unsigned End_i;
  unsigned long Blocks_l;
  bool Boot_b;
  bool operator ==(const PartInfo& Rhs_rv)
  {
    return (Start_i == Rhs_rv.Start_i &&
	    End_i == Rhs_rv.End_i &&
	    Blocks_l == Rhs_rv.Blocks_l &&
	    PType_e == Rhs_rv.PType_e &&
	    Device_C == Rhs_rv.Device_C &&
	    Info_C == Rhs_rv.Info_C &&
	    Id_i == Rhs_rv.Id_i &&
	    Num_i == Rhs_rv.Num_i );
  }
};

#define IsSwap( A ) ((A).PType_e==PAR_TYPE_SWAP||(A).Filesys_e==FS_TYPE_SWAP)
#define IsLinuxPart( A ) ((A).PType_e==PAR_TYPE_LINUX || \
                          (A).PType_e==PAR_TYPE_RAID_PV || \
                          (A).PType_e==PAR_TYPE_LVM_PV)

#define PartInfoEQ( A, B ) ((A)==(B))

#endif
