// -*- C++ -*-
// Maintainer: fehr@suse.de

#ifndef _FdiskAcc_h
#define _FdiskAcc_h


#include <string>
#include <vector>

using std::vector;

class InterCmd;

#include "PartInfo.defs.h"
#include "SystemCmd.h"
#include "DiskAcc.h"

class FdiskAccess : public DiskAccess
{
public:
  FdiskAccess(string Disk_Cv, bool Readonly_bv);
  virtual ~FdiskAccess();
  virtual bool WritePartitionTable();
  virtual void SetType(const unsigned Part_iv, const unsigned Type_iv);
  virtual void Delete(const unsigned Part_iv);
  virtual bool NewPartition(const PartitionType Part_e, const unsigned Part_nr,
		            string Von_Cv, string Bis_Cv, 
			    const unsigned Type_iv);
  virtual void DeleteAll();

protected:
  string GetPartitionNumber(int Part_iv);
  void SendQuit();
  void CheckOutput(SystemCmd& Cmd_C, string Pat_Cv);
  void CheckOutputStd(SystemCmd& Cmd_C, string Disk_Cv);
  void CheckOutputBsd(SystemCmd& Cmd_C, string Disk_Cv);
  bool IsBsdLine(string Line_Cv);
  bool IsPdiskLine(string Line_Cv);
  void ScanFdiskLine(string Line_Cv, PartInfo& Part_rr);
  void ScanPdiskLine(string Line_Cv, PartInfo& Part_rr, string Disk_Cv);
  void ScanBsdLine(string Line_Cv, PartInfo& Part_rr, string Disk_Cv);
  void SetTypeStd(const unsigned Part_iv, const unsigned Type_iv);
  void SetTypeBsd(const unsigned Part_iv, const unsigned Type_iv);
  bool NewPartitionStd(const PartitionType Part_e, 
		       const unsigned Part_nr, string Von_Cv,
		       string Bis_Cv);
  bool NewPartitionBsd(const unsigned Part_nr, string Von_Cv,
		       string Bis_Cv);
  void CheckWritable();
  void SendPrint();
  InterCmd *Fdisk_pC;
};

#endif
