// Maintainer: fehr@suse.de

#include <set>
#include <YCP.h>
#include <ycp/YCPParser.h>
#include "PartInfo.defs.h"
#include "LvmAgent.h"
#include <ycp/y2log.h>

LvmAgent::LvmAgent()
{
    Lvm_pC = new LvmAccess();
}


LvmAgent::~LvmAgent()
{
    delete Lvm_pC;
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
LvmAgent::Read(const YCPPath& path, const YCPValue& arg)
{
  y2debug("LvmAgent::Read Path:%s length:%ld", path->toString().c_str(),
          path->length() );
  if (path->length() < 1) {
      y2error("Path '%s' has incorrect length", path->toString().c_str());
      return YCPVoid();
  }

  string conf_name = path->component_str(0);

  y2milestone("cmd '%s'", conf_name.c_str());

  if (conf_name == "vg")
      {
      YCPMap Ret_Ci;
      for ( unsigned i=0; i<Lvm_pC->VgCnt(); i++ )
	{
	  YCPMap* VgMap_pCi = new YCPMap;
	  YCPMap* PvMap_pCi = new YCPMap;
	  YCPMap* LvMap_pCi = new YCPMap;
	  YCPMap& PvMap_Ci( *PvMap_pCi );
	  YCPMap& LvMap_Ci( *LvMap_pCi );
	  YCPMap& VgMap_Ci( *VgMap_pCi );

	  VgInfo Vg_Ci = Lvm_pC->GetVg( i );
	  VgMap_Ci = CreateVgMap( Vg_Ci );

	  for ( list<PvInfo>::iterator j=Vg_Ci.Pv_C.begin();
	        j!=Vg_Ci.Pv_C.end(); j++ )
	      {
	      PvMap_Ci->add( YCPString( j->Name_C ), CreatePvMap( *j ) );
	      }

	  for ( list<LvInfo>::iterator j=Vg_Ci.Lv_C.begin();
	        j!=Vg_Ci.Lv_C.end(); j++ )
	      {
	      LvMap_Ci->add( YCPString( j->Name_C ), CreateLvMap( *j ) );
	      }

	  VgMap_Ci->add( YCPString ("pv"), PvMap_Ci );
	  VgMap_Ci->add( YCPString ("lv"), LvMap_Ci );

	  Ret_Ci->add( YCPString( Vg_Ci.Name_C ), *VgMap_pCi );

	  delete VgMap_pCi;
	  delete PvMap_pCi;
	  delete LvMap_pCi;
	}
      return Ret_Ci;
      }
  else if (conf_name == (string)"pv")
      {
      YCPMap Ret_Ci;
      for( unsigned i=0; i<Lvm_pC->PvCnt(); i++ )
	  {
	  PvInfo Pv_Ci = Lvm_pC->GetPv( i );
	  Ret_Ci->add( YCPString( Pv_Ci.Name_C ), CreatePvMap( Pv_Ci ) );
	  }
      return Ret_Ci;
      }
  else if (conf_name == (string)"lv")
      {
      YCPMap Ret_Ci;
      for ( unsigned i=0; i<Lvm_pC->LvCnt(); i++ )
	  {
	  LvInfo Lv_Ci = Lvm_pC->GetLv( i );
	  Ret_Ci->add( YCPString( Lv_Ci.Name_C ), CreateLvMap( Lv_Ci ) );
	  }
      return Ret_Ci;
      }
  else
      {
      y2error("unknown command in path '%s'", path->toString().c_str());
      return YCPVoid();
      }
  }

YCPMap LvmAgent::CreateVgMap( const VgInfo& Vg_Cv )
    {
    YCPMap VgMap_Ci;
    VgMap_Ci->add( YCPString ("blocks"), YCPInteger( Vg_Cv.Blocks_l ));
    VgMap_Ci->add( YCPString ("free"), YCPInteger( Vg_Cv.Free_l ));
    VgMap_Ci->add( YCPString ("pesize"), YCPInteger( Vg_Cv.PeSize_l ));
    VgMap_Ci->add( YCPString ("active"), YCPBoolean( Vg_Cv.Active_b ));
    return( VgMap_Ci );
    }

YCPMap LvmAgent::CreateLvMap( const LvInfo& Lv_Cv )
    {
    YCPMap LvMap_Ci;
    LvMap_Ci->add( YCPString( "vgname" ), YCPString( Lv_Cv.VgName_C ));
    LvMap_Ci->add( YCPString( "writeable" ), YCPBoolean( Lv_Cv.Writable_b ));
    LvMap_Ci->add( YCPString( "active" ), YCPBoolean( Lv_Cv.Active_b ));
    LvMap_Ci->add( YCPString( "contiguous" ), YCPBoolean( Lv_Cv.AllocCont_b ));
    LvMap_Ci->add( YCPString( "blocks" ), YCPInteger( Lv_Cv.Blocks_l ));
    LvMap_Ci->add( YCPString( "stripe" ), YCPInteger( Lv_Cv.Stripe_l ));
    return( LvMap_Ci );
    }

YCPMap LvmAgent::CreatePvMap( const PvInfo& Pv_Cv )
    {
    YCPMap PvMap_Ci;
    YCPList PvPartListCi;
    PvMap_Ci->add( YCPString( "vgname" ), YCPString( Pv_Cv.VgName_C ));
    PvMap_Ci->add( YCPString( "allocatable" ),
		   YCPBoolean( Pv_Cv.Allocatable_b ));
    PvMap_Ci->add( YCPString( "active" ), YCPBoolean( Pv_Cv.Active_b ));
    PvMap_Ci->add( YCPString( "created" ), YCPBoolean( Pv_Cv.Created_b ));
    PvMap_Ci->add( YCPString( "blocks" ), YCPInteger( Pv_Cv.Blocks_l ));
    PvMap_Ci->add( YCPString( "free" ), YCPInteger( Pv_Cv.Free_l ));
    for( list<string>::const_iterator k=Pv_Cv.RealDevList_C.begin();
	 k!=Pv_Cv.RealDevList_C.end(); k++ )
	{
	PvPartListCi->add( YCPString( *k ));
	}
    PvMap_Ci->add( YCPString( "devices" ), PvPartListCi );
    return( PvMap_Ci );
    }

YCPValue
LvmAgent::Write( const YCPPath& path, const YCPValue& value,
		 const YCPValue& arg )
    {
    y2milestone(" new LvmAgent::Write" );
    y2debug("LvmAgent::Write(%s, %s)", path->toString().c_str(),
	    value.isNull()?"nil":value->toString().c_str());
    YCPBoolean ret(true);

    if (path->length() < 1)
	{
	y2error("Path '%s' has incorrect length", path->toString().c_str());
	return YCPVoid();
	}

    string conf_name = path->component_str(0);

    y2milestone("cmd '%s'", conf_name.c_str());

    if (conf_name == "command")
	{
	YCPMap Ret_Ci;
	YCPMap cmd;
	YCPValue type = YCPNull();
	string CmdLine_Ci;
	string ErrText_Ci;

	if (value.isNull() || !value->isMap())
	    {
	    ErrText_Ci = "invalid lvm cmd";
	    y2error("invalid lvm cmd: %s", value->toString().c_str());
	    ret = false;
	    }
	else
	    {
	    cmd = value->asMap();
	    type = cmd->value(YCPString("type"));
	    }
	y2debug("isNull:%d", type.isNull() );

	if( !type.isNull() && type->isString() )
	    {
	    string type_string = type->asString()->value();
	    y2milestone("cmd %s", type_string.c_str());
	    if( type_string == "create_lv" )
		{
		string name;
		unsigned long size = 0;
		string vgname;
		unsigned long stripes = 1;
		YCPValue content = cmd->value(YCPString("name"));
		if( !content.isNull() && content->isString())
		    {
		    name = content->asString()->value();
		    }
		content = cmd->value(YCPString("vgname"));
		if( !content.isNull() && content->isString())
		    {
		    vgname = content->asString()->value();
		    }
		content = cmd->value(YCPString("size"));
		y2debug( "isInt:%d val:%s", content->isInteger(),
			 content->toString().c_str() );
		if( !content.isNull() && content->isInteger())
		    {
		    size = content->asInteger()->value()/1024;
		    }
		content = cmd->value(YCPString("stripes"));
		if( !content.isNull() && content->isInteger())
		    {
		    stripes = content->asInteger()->value();
		    }
		y2milestone("name:%s vgname:%s size:%ld stripes:%ld",
			     name.c_str(), vgname.c_str(), size,
			     stripes );
		if( name.length()>0 && vgname.length()>0 && size>0 )
		    {
		    if( !Lvm_pC->CreateLv( name, vgname, size, stripes ))
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "lvm create_lv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "resize_lv" )
		{
		string name;
		unsigned long size = 0;
		string vgname;
		YCPValue content = cmd->value(YCPString("name"));
		if( !content.isNull() && content->isString())
		    {
		    name = content->asString()->value();
		    }
		content = cmd->value(YCPString("vgname"));
		if( !content.isNull() && content->isString())
		    {
		    vgname = content->asString()->value();
		    }
		content = cmd->value(YCPString("size"));
		if( !content.isNull() && content->isInteger())
		    {
		    size = content->asInteger()->value()/1024;
		    }
		string lv_name = (string)"/dev/" + vgname + "/" + name;
		y2milestone("name:%s vgname:%s new size:%ld lv_name:%s",
			     name.c_str(), vgname.c_str(), size,
			     lv_name.c_str() );
		if( name.length()>0 && vgname.length()>0 && size>0 )
		    {
		    if( !Lvm_pC->ChangeLvSize( lv_name, size ) )
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "lvm resize_lv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "remove_lv" )
		{
		string name;
		string vgname;
		YCPValue content = cmd->value(YCPString("name"));
		if( !content.isNull() && content->isString())
		    {
		    name = content->asString()->value();
		    }
		content = cmd->value(YCPString("vgname"));
		if( !content.isNull() && content->isString())
		    {
		    vgname = content->asString()->value();
		    }
		string lv_name = (string)"/dev/" + vgname + "/" + name;
		y2milestone("name:%s vgname:%s lv_name:%s",
			    name.c_str(), vgname.c_str(),
			    lv_name.c_str());
		if( name.length()>0 && vgname.length()>0 )
		    {
		    if( !Lvm_pC->DeleteLv( lv_name ) )
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "lvm remove_lv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "create_vg" )
		{
		unsigned long size = 4096;
		string vgname;
		list<string> devices;
		YCPValue content = cmd->value(YCPString("vgname"));
		if( !content.isNull() && content->isString())
		    {
		    vgname = content->asString()->value();
		    }
		content = cmd->value(YCPString("pesize"));
		if( !content.isNull() && content->isInteger())
		    {
		    size = content->asInteger()->value()/1024;
		    }
		content = cmd->value(YCPString("devices"));
		y2debug( "isNull:%d", content.isNull() );
		y2debug( "isList:%d", content->isList() );
		if( !content.isNull() && content->isList())
		    {
		    YCPList devs = content->asList();
		    y2debug( "size:%d", devs->size() );
		    for( int i=0; i<devs->size(); i++ )
			{
			y2debug( "i:%d isString:%d len:%d",
				  i, devs->value(i)->isString(),
				  devs->value(i)->asString()->value().length() );
			if( devs->value(i)->isString() &&
			    devs->value(i)->asString()->value().length()>0 )
			    {
			    devices.push_back(devs->value(i)->asString()->value());

			    }
			}
		    }
		y2debug("vgname:%s pesize:%ld devices:%d",
			vgname.c_str(), size, devices.size() );
		if( vgname.length()>0 && size>0 && devices.size()>0 )
		    {
		    if( !Lvm_pC->CreateVg( vgname, size, devices ) )
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    else if( !Lvm_pC->ChangeActive( vgname, true ) )
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "lvm create_vg invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "remove_vg" )
		{
		string vgname;
		YCPValue content = cmd->value(YCPString("vgname"));
		if( !content.isNull() && content->isString())
		    {
		    vgname = content->asString()->value();
		    }
		y2milestone("vgname:%s", vgname.c_str());
		if( vgname.length()>0 )
		    {
		    if( !Lvm_pC->DeleteVg( vgname ) )
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "lvm remove_vg invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "create_pv" )
		{
		string vgname;
		string device;
		YCPValue content = cmd->value(YCPString("vgname"));
		if( !content.isNull() && content->isString())
		    {
		    vgname = content->asString()->value();
		    }
		content = cmd->value(YCPString("device"));
		if( !content.isNull() && content->isString())
		    {
		    device = content->asString()->value();
		    }
		y2milestone("vgname:%s device:%s",
			     vgname.c_str(), device.c_str() );
		if( device.length()>0 )
		    {
		    if( !Lvm_pC->CreatePv( device ) )
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    else if( vgname.length()>0 )
			{
			if( !Lvm_pC->ExtendVg( vgname, device ) )
			    {
			    ErrText_Ci = Lvm_pC->GetErrorText();
			    CmdLine_Ci = Lvm_pC->GetCmdLine();
			    y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			    ret = false;
			    }
			}
		    }
		else
		    {
		    ErrText_Ci = "lvm create_pv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "remove_pv" )
		{
		string vgname;
		string device;
		YCPValue content = cmd->value(YCPString("vgname"));
		if( !content.isNull() && content->isString())
		    {
		    vgname = content->asString()->value();
		    }
		content = cmd->value(YCPString("device"));
		if( !content.isNull() && content->isString())
		    {
		    device = content->asString()->value();
		    }
		y2milestone("vgname:%s device:%s",
			     vgname.c_str(), device.c_str() );
		if( device.length()>0 && vgname.size()>0 )
		    {
		    if( !Lvm_pC->ShrinkVg( vgname, device ) )
			{
			ErrText_Ci = Lvm_pC->GetErrorText();
			CmdLine_Ci = Lvm_pC->GetCmdLine();
			y2error( "lvm error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "lvm remove_pv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else
		{
		ErrText_Ci = "lvm invalid cmd";
		y2error( ErrText_Ci.c_str() );
		ret = false;
		}
	    }
	else
	    {
	    ErrText_Ci = "no type entry";
	    y2error( ErrText_Ci.c_str() );
	    ret = false;
	    }
	if( !ret->asBoolean()->value() )
	    {
	    Ret_Ci->add( YCPString( "errtxt" ), YCPString( ErrText_Ci ) );
	    if( CmdLine_Ci.length()>0 )
		{
		Ret_Ci->add( YCPString( "cmdline" ), YCPString( CmdLine_Ci ) );
		}
	    }
	Ret_Ci->add( YCPString( "ok" ), YCPBoolean( ret ));
	return Ret_Ci;
	}
    else if (conf_name == "init")
	{
	y2milestone( "re-initialize Agent" );
	delete( Lvm_pC );
	Lvm_pC = new LvmAccess();
	return( ret );
	}
    else if (conf_name == "deactivate")
	{
	y2milestone( "deactivate all LVM VGs" );
	ret = Lvm_pC->ActivateVGs( false );
	return( ret );
	}
    else if (conf_name == "activate")
	{
	y2milestone( "activate all LVM VGs" );
	ret = Lvm_pC->ActivateVGs( true );
	return( ret );
	}
    else
	{
	y2error( "unknown or readonly path %s", path->toString().c_str());
	}
    return YCPVoid();
    }

YCPValue LvmAgent::Dir(const YCPPath& path)
{
  return YCPList();
}

