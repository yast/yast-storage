// -*- C++ -*-
// Maintainer: fehr@suse.de

#ifndef _PartedAcc_h
#define _PartedAcc_h


#include <string>
#include <vector>

using std::vector;

#include "PartInfo.defs.h"
#include "SystemCmd.h"
#include "DiskAcc.h"

class PartedAccess : public DiskAccess
{
public:
  PartedAccess(string Disk_Cv, bool Readonly_bv);
  virtual ~PartedAccess();
  virtual bool WritePartitionTable() { return false; };
  virtual void Delete(const unsigned Part_iv);
  virtual void DeleteAll();
  virtual bool NewPartition(const PartitionType Part_e, const unsigned Part_nr,
		            string Von_Cv, string Bis_Cv, 
			    const unsigned Type_iv );
  bool Resize( const unsigned Part_iv, const unsigned NewLastCyl_iv );
  virtual void SetType(const unsigned Part_iv, const unsigned Type_iv);

protected:
  void CheckError( const string& CmdString_Cv, SystemCmd& Cmd_C );

  string GetPartitionNumber(int Part_iv);
  void CheckOutput(SystemCmd& Cmd_C, string Pat_Cv);
  bool ScanLine(string Line_Cv, PartInfo& Part_rr);
  void GetPartitionList();
};

#endif
