// Maintainer: fehr@suse.de

#ifndef _MdAccess_h
#define _MdAccess_h

#include <string>
#include <list>

using std::list;

struct MdInfo
    {
    string Name_C;
    unsigned long Blocks_l;
    unsigned long ChunkSize_l;
    unsigned Nr_i;
    unsigned UsedDisks_i;
    unsigned ValDisks_i;
    bool PersistentSuper_b;
    bool Spare_b;
    string RaidType_C;
    string ParityAlg_C;
    list<string> DevList_C;
    };

class MdAccess
    {
    public:
	MdAccess();
	virtual ~MdAccess();
	unsigned Cnt();
	MdInfo GetMd( int Idx_ii );
	bool GetMd( const string& Device_Cv, MdInfo& Val_Cr );
	bool ActivateMDs( bool Activate_bv=true );

    protected:
	list<MdInfo>::iterator FindMd( const string& Device_Cv );
	list<MdInfo> List_C;
	void ReadMdData();
    };

#endif
