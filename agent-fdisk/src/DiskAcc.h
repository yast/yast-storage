// -*- C++ -*-
// Maintainer: fehr@suse.de

#ifndef _DiskAcc_h
#define _DiskAcc_h


#include <string>
#include <vector>

using std::vector;

#include "PartInfo.defs.h"
#include "SystemCmd.h"

class DiskAccess
{
public:
  DiskAccess(string Disk_Cv);
  virtual ~DiskAccess();

  string Disk();
  unsigned long CylinderToKb(int Cyl_iv);
  int KbToCylinder(unsigned long Kb_lv);
  unsigned long CapacityInKb();
  int  NumCylinder();
  unsigned PrimaryMax();
  bool Changed() { return Changed_b; };
  vector<PartInfo>& Partitions();
  string DiskLabel();

  static string GetDiskName(string Part_Cv);
  static int GetPartNumber(const string& Part_Cv);
  static bool IsKnownDevice(const string& Part_Cv);


  virtual bool WritePartitionTable() { return false; };
  virtual void Delete(const unsigned Part_iv) {};
  virtual void DeleteAll() {};
  virtual bool NewPartition(const PartitionType Part_e, const unsigned Part_nr,
		            string Von_Cv, string Bis_Cv, 
			    const unsigned Type_iv,
			    string DefLabel_Cv ) { return false; };
  virtual void SetType(const unsigned Part_iv, const unsigned Type_iv) {};
  string Stderr();

protected:
  string GetPartDeviceName(int Num_iv);
  string GetPartDeviceName(int Num_iv, string Disk_Cv);

  string Stderr_C;
  string Disk_C;
  string Label_C;
  unsigned Head_i;
  unsigned Cylinder_i;
  unsigned Sector_i;
  unsigned long ByteCyl_l;
  bool Changed_b;
  bool BsdLabel_b;
  vector<PartInfo> Part_C;
};

#endif
