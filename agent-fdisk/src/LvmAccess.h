// Maintainer: fehr@suse.de

#ifndef _LvmAccess_h
#define _LvmAccess_h

#include <string>
#include <list>

using std::list;

#include "PartInfo.defs.h"
#include "SystemCmd.h"

struct PvInfo
    {
    string Name_C;
    string VgName_C;
    bool Allocatable_b;
    bool Active_b;
    bool Created_b;
    int PartitionId_i;
    unsigned long Blocks_l;
    unsigned long Free_l;
    list<string> RealDevList_C;
    };

struct LvInfo
    {
    string Name_C;
    string VgName_C;
    bool Writable_b;
    bool Active_b;
    bool AllocCont_b;
    unsigned long Stripe_l;
    unsigned long Blocks_l;
    };

struct VgInfo
    {
    string Name_C;
    unsigned long Blocks_l;
    unsigned long Free_l;
    unsigned long PeSize_l;
    bool Active_b;
    list<PvInfo> Pv_C;
    list<LvInfo> Lv_C;
    };

class LvmAccess
    {
    public:
	LvmAccess( bool Expensive_bv=true );
	virtual ~LvmAccess();
	unsigned VgCnt();
	unsigned PvCnt();
	unsigned LvCnt();
	int GetVgIdx( const string& VgName_Cv );
	int GetPvIdx( const string& PvName_Cv );
	VgInfo GetVg( int Idx_ii );
	LvInfo GetLv( int Idx_ii );
	PvInfo GetPv( int Idx_ii );
	void ChangeId( int Idx_ii, int Id_iv );
	void ChangePvVgName( const string& Device_Cv, const string& Name_Cv );
	void DoExpensive();
	bool CreatePv( const string& PvName_Cv );
	string GetErrorText();
	string GetCmdLine();
	bool ChangeActive( const string& Name_Cv, bool Active_bv );
	bool DeleteVg( const string& VgName_Cv );
	bool ExtendVg( const string& VgName_Cv, const string& PvName_Cv );
	bool ShrinkVg( const string& VgName_Cv, const string& PvName_Cv );
	bool CreateVg( const string& VgName_Cv, unsigned long PeSize_lv,
	               list<string>& Devices_Cv );
	bool CreateLv( const string& LvName_Cv, const string& VgName_Cv,
	               unsigned long Size_lv, unsigned long Stripe_lv );
	bool ChangeLvSize( const string& LvName_Cv, unsigned long Size_lv );
	bool DeleteLv( const string& LvName_Cv );
	void UpdateDisk( list<PartInfo>& Part_Cv, const string& Disk_Cv );
	void ActivateLvm();
	bool ActivateVGs( bool Activate_bv=true );
	list<string> PhysicalDeviceList();
	static unsigned long long UnitToValue( const string& Unit_Cv );

    protected:
	struct VgIntern
	    {
	    string Name_C;
	    unsigned long Blocks_l;
	    unsigned long Free_l;
	    unsigned long PeSize_l;
	    bool Active_b;
	    list<PvInfo*> Pv_C;
	    list<LvInfo*> Lv_C;
	    operator VgInfo();
	    };

	void ProcessMd();
	void ScanForDisks();
	void ScanForInactiveVg();
	void ScanProcLvm();
	void PrepareLvmCmd();
	list<PvInfo>::iterator SortIntoPvList( const PvInfo& PvElem_rv );
	bool ExecuteLvmCmd( const string& Cmd_Cv );
	bool MountRamdisk( const string& Path_Cv, unsigned SizeMb_iv );
	string GetPvDevicename( const string& VgName_Cv, const string& Dev_Cv,
				int Num_iv );


	list<VgIntern>::iterator FindVg( const string& Name_Cv );
	list<PvInfo>::iterator FindPv( const string& Device_Cv );
	list<LvInfo>::iterator FindLv( const string& Name_Cv );
	list<VgIntern> VgList_C;
	list<PvInfo> PvList_C;
	list<LvInfo> LvList_C;
	bool Expensive_b;
	SystemCmd LvmCmd_C;
	string LvmOutput_C;
	string CmdLine_C;
	int LvmRet_i;
    };

#endif
