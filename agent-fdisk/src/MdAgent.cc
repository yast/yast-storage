// Maintainer: fehr@suse.de

#include <set>
#include <YCP.h>
#include <ycp/YCPParser.h>
#include "MdAgent.h"
#include <ycp/y2log.h>

MdAgent::MdAgent()
{
Md_pC = new MdAccess();
}


MdAgent::~MdAgent()
{
delete Md_pC;
}


//
// path is <device>.<command>
//
// <device> might have multiple parts which are converted
//   to file paths.
//  i.e. <device> == hda		==> /dev/hda
//	 <device> == raid.dev.cz	==> /dev/raid/dev/cz
//
// <command> is always the last part of 'path'
//

YCPValue
MdAgent::Read(const YCPPath& path, const YCPValue& arg)
{
  if (path->length() < 1) {
      y2error("Path '%s' has incorrect length", path->toString().c_str());
      return YCPVoid();
  }

  string cmd_name = path->component_str(0);

  if (cmd_name == "config")
    {
    YCPMap Ret_Ci;
    for ( unsigned i=0; i<Md_pC->Cnt(); i++ )
	{
	YCPMap* MdMap_pCi = new YCPMap;
	YCPMap& MdMap_Ci( *MdMap_pCi );

	MdInfo Md_Ci = Md_pC->GetMd( i );
	MdMap_Ci = CreateMdMap( Md_Ci );
	Ret_Ci->add( YCPString( Md_Ci.Name_C ), MdMap_Ci );
	delete MdMap_pCi;
	}
    return Ret_Ci;
    }
  else
    {
    y2error("unknown command in path '%s'", path->toString().c_str());
    return YCPVoid();
    }
}

YCPMap
MdAgent::CreateMdMap( const MdInfo& Md_Cv )
    {
    YCPMap Map_Ci;
    YCPList PartListCi;

    Map_Ci->add( YCPString( "blocks" ), YCPInteger( Md_Cv.Blocks_l ));
    if( Md_Cv.ChunkSize_l>0 )
	{
	Map_Ci->add( YCPString( "chunk" ), YCPInteger( Md_Cv.ChunkSize_l ));
	}
    Map_Ci->add( YCPString( "nr" ), YCPInteger( Md_Cv.Nr_i ));
    Map_Ci->add( YCPString( "val_disks" ), YCPInteger( Md_Cv.ValDisks_i ));
    Map_Ci->add( YCPString( "used_disks" ), YCPInteger( Md_Cv.UsedDisks_i ));
    Map_Ci->add( YCPString( "persistent_superblock" ),
                 YCPBoolean( Md_Cv.PersistentSuper_b ));
    if( Md_Cv.ParityAlg_C.length()>0 )
	{
	Map_Ci->add( YCPString( "parity_algorithm" ),
		     YCPString( Md_Cv.ParityAlg_C ));
	}
    Map_Ci->add( YCPString( "raid_type" ), YCPString( Md_Cv.RaidType_C ));
    for( list<string>::const_iterator k=Md_Cv.DevList_C.begin();
	 k!=Md_Cv.DevList_C.end(); k++ )
	{
	PartListCi->add( YCPString( *k ));
	}
    Map_Ci->add( YCPString( "devices" ), PartListCi );

    return( Map_Ci );
    }

YCPValue
MdAgent::Write(const YCPPath& path, const YCPValue& value,
               const YCPValue& arg)
    {
    y2debug("MdAgent::Write(%s, %s)", path->toString().c_str(),
          value.isNull()?"nil":value->toString().c_str());
    if (path->length() < 1)
        {
        y2error("Path '%s' has incorrect length", path->toString().c_str());
        return YCPVoid();
        }
    string conf_name = path->component_str(0);
    YCPBoolean ret(true);

    y2milestone("cmd '%s'", conf_name.c_str());

    if (conf_name == "init")
        {
        y2milestone( "re-initialize Agent" );
        delete( Md_pC );
        Md_pC = new MdAccess();
        return( ret );
        }
    else if (conf_name == "deactivate")
        {
        y2milestone( "deactivate all MDs" );
        ret = Md_pC->ActivateMDs( false );
        return( ret );
        }
    else if (conf_name == "activate")
        {
        y2milestone( "activate all MDs" );
        ret = Md_pC->ActivateMDs( true );
        return( ret );
        }
    else
	{
	y2error( "unknown or readonly path %s", path->toString().c_str());
	}
    return YCPVoid();
    }

YCPValue MdAgent::Dir(const YCPPath& path)
{
  return YCPList();
}

