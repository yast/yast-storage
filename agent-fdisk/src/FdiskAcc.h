// -*- C++ -*-
// Maintainer: schwab@suse.de

#ifndef _FdiskAcc_h
#define _FdiskAcc_h


#include <string>
#include <vector>

using std::vector;

class InterCmd;

#include "PartInfo.defs.h"
#include "SystemCmd.h"

class FdiskAccess
{
public:
  FdiskAccess(string Disk_Cv, bool Readonly_bv);
  virtual ~FdiskAccess();
  unsigned PartitionCnt();
  unsigned LogicalCnt();
  unsigned PrimaryCnt();
  unsigned PrimaryMax();
  PartInfo& operator[](unsigned int Idx_iv);
  void SendQuit();
  bool WritePartitionTable();
  void SetType(const unsigned Part_iv, const unsigned Type_iv);
  void Delete(const unsigned Part_iv);
  bool NewPartition(const PartitionType Part_e, const unsigned Part_nr,
		    string Von_Cv, string Bis_Cv);
  string Stderr();
  string GetPartDeviceName(int Num_iv);
  static string GetPartDeviceName(int Num_iv, string Disk_Cv);
  static string GetDiskName(string Part_Cv);
  static int GetPartNumber(const string& Part_Cv);
  static bool IsKnownDevice(const string& Part_Cv);

  string Disk();
  unsigned long CapacityInKb();
  int  KbToCylinder(unsigned long Kb_lv);
  unsigned long CylinderToKb(int Cyl_iv);
  int  NumCylinder();
  void  DeleteAll();
  bool DelPossible(const unsigned Nr_iv);
  bool SetPossible(const unsigned Nr_iv);
  bool NewPossible(const unsigned Nr_iv);
  bool PrimaryPossible();
  bool ExtendedPossible();
  bool LogicalPossible();
  bool PrimaryExists(const unsigned Nr_iv);
  bool Changed() { return Changed_b; };
  vector<PartInfo>& Partitions();
  vector<string>& DiskList();
  bool GetFreeArea(const bool Extended_bv, unsigned& Von_ir,
		   unsigned& Bis_ir);
  void GetFsysType();
  bool BsdLabel() { return BsdLabel_b; }
  static int InodesFromBlock(const int Block_iv);

protected:
  void CheckOutput(SystemCmd& Cmd_C, string Pat_Cv);
  void CheckOutputStd(SystemCmd& Cmd_C, string Disk_Cv);
  void CheckOutputBsd(SystemCmd& Cmd_C, string Disk_Cv);
  bool IsBsdLine(string Line_Cv);
  bool IsPdiskLine(string Line_Cv);
  void ScanFdiskLine(string Line_Cv, PartInfo& Part_rr);
  void ScanPdiskLine(string Line_Cv, PartInfo& Part_rr, string Disk_Cv);
  void ScanBsdLine(string Line_Cv, PartInfo& Part_rr, string Disk_Cv);
  string GetPartitionNumber(int Part_iv);
  void SetTypeStd(const unsigned Part_iv, const unsigned Type_iv);
  void SetTypeBsd(const unsigned Part_iv, const unsigned Type_iv);
  bool NewPartitionStd(const PartitionType Part_e, 
		       const unsigned Part_nr, string Von_Cv,
		       string Bis_Cv);
  bool NewPartitionBsd(const unsigned Part_nr, string Von_Cv,
		       string Bis_Cv);
  void CheckWritable();
  void SendPrint();
  vector<PartInfo>::iterator ExtendedIndex();
  vector<PartInfo>::iterator GetPartitionAfter(const unsigned Nr_iv,
					       const bool IgnoreLogical_bv);
  bool CheckFreeBlocks(const bool Extended_bv, unsigned& Von_ir,
		       unsigned& Bis_ir);
  string Stderr_C;
  string Disk_C;
  int Head_i;
  int Cylinder_i;
  int Sector_i;
  unsigned long ByteCyl_l;
  bool Changed_b;
  bool BsdLabel_b;
  InterCmd *Fdisk_pC;
  vector<PartInfo> Part_C;
  vector<string> DiskList_C;
};

#endif
