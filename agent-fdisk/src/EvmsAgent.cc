// Maintainer: fehr@suse.de

#include <set>
#include <sstream>

#include <YCP.h>
#include "PartInfo.defs.h"
#include "EvmsAgent.h"
#include <ycp/y2log.h>

EvmsAgent::EvmsAgent()
{
    Evms_pC = new EvmsAccess();
}


EvmsAgent::~EvmsAgent()
{
    delete Evms_pC;
}


YCPValue
EvmsAgent::Read(const YCPPath& path, const YCPValue& arg, const YCPValue& )
{
  y2milestone( "EvmsAgent::Read Path:%s length:%ld", path->toString().c_str(),
	       path->length() );
  if( path->length() < 1) 
      {
      y2error("Path '%s' has incorrect length", path->toString().c_str());
      return YCPVoid();
      }

  string conf_name = path->component_str(0);

  y2milestone("cmd '%s'", conf_name.c_str());

  if (conf_name == "volume")
      {
      YCPList Ret_Ci;
      list<const EvmsVolumeObject*> l;
      Evms_pC->ListVolumes( l );
      for( list<const EvmsVolumeObject*>::iterator i=l.begin(); 
           i != l.end(); i++ )
	  {
	  Ret_Ci->add( CreateVolumeMap( **i ) );
	  }
      return Ret_Ci;
      }
  else if (conf_name == "container")
      {
      YCPList Ret_Ci;
      list<const EvmsContainerObject*> l;
      Evms_pC->ListContainer( l );
      for( list<const EvmsContainerObject*>::iterator i=l.begin();
	   i != l.end(); i++ )
	   {  
	   Ret_Ci->add( CreateContainerMap( **i ) );
	   }
      return Ret_Ci;
      }
  else if (conf_name == (string)"error" )
      {
      return Err_C;
      }
  else
      {
      y2error("unknown command in path '%s'", path->toString().c_str());
      }
  return YCPVoid();
  }

YCPMap EvmsAgent::CreateVolumeMap( const EvmsVolumeObject& Vol_Cv )
    {
    YCPMap Map_Ci;
    y2debug( "Id %d", Vol_Cv.Id() );
    std::ostringstream s; s<<Vol_Cv; y2debug( "%s", s.str().c_str() );
    Map_Ci->add( YCPString ("evms_id"), YCPInteger( Vol_Cv.Id() ));
    Map_Ci->add( YCPString ("size"), YCPInteger( Vol_Cv.SizeK() ));
    Map_Ci->add( YCPString ("device"), YCPString( Vol_Cv.Device() ));
    if( Vol_Cv.Native() )
	{
	Map_Ci->add( YCPString ("native"), YCPBoolean( Vol_Cv.Native() ));
	}
    if( Vol_Cv.Consumes() )
	{
	YCPList Tmp_Ci;
	Tmp_Ci->add( YCPString( Vol_Cv.Consumes()->Name() ));
	Map_Ci->add( YCPString ("consumes"), Tmp_Ci );
	}
    if( Vol_Cv.AssVol() )
	{
	YCPList Tmp_Ci;
	Tmp_Ci->add( YCPString( Vol_Cv.AssVol()->Name() ));
	Map_Ci->add( YCPString ("associated"), Tmp_Ci );
	}
    if( Vol_Cv.ConsumedBy() )
	{
	YCPList Tmp_Ci;
	Tmp_Ci->add( YCPString( Vol_Cv.ConsumedBy()->Name() ));
	Map_Ci->add( YCPString ("consumed_by"), Tmp_Ci );
	}
    return( Map_Ci );
    }

YCPMap EvmsAgent::CreateContainerMap( const EvmsContainerObject& Vol_Cv )
    {
    YCPMap Map_Ci;
    y2debug( "Id %d", Vol_Cv.Id() );
    std::ostringstream s; s<<Vol_Cv; y2debug( "%s", s.str().c_str() );
    Map_Ci->add( YCPString ("evms_id"), YCPInteger( Vol_Cv.Id() ));
    Map_Ci->add( YCPString ("size"), YCPInteger( Vol_Cv.SizeK() ));
    Map_Ci->add( YCPString ("free"), YCPInteger( Vol_Cv.FreeK() ));
    Map_Ci->add( YCPString ("name"), YCPString( Vol_Cv.Name() ));
    Map_Ci->add( YCPString ("type"), YCPString( Vol_Cv.TypeName() ));
    Map_Ci->add( YCPString ("pesize"), YCPInteger( Vol_Cv.PeSize() ));
    YCPList Cons_Ci;
    YCPList Creates_Ci;
    const list<EvmsObject *> cons_list = Vol_Cv.Consumes();
    for( list<EvmsObject *>::const_iterator i=cons_list.begin(); 
         i!=cons_list.end(); i++ )
	{
	Cons_Ci->add( YCPString( (*i)->Name() ));
	}
    const list<EvmsObject *> crea_list = Vol_Cv.Creates();
    for( list<EvmsObject *>::const_iterator i=crea_list.begin(); 
         i!=crea_list.end(); i++ )
	{
	Creates_Ci->add( YCPString( (*i)->Name() ));
	}
    Map_Ci->add( YCPString ("consumes"), Cons_Ci );
    Map_Ci->add( YCPString ("creates"), Creates_Ci );
    return( Map_Ci );
    }

YCPBoolean
EvmsAgent::Write( const YCPPath& path, const YCPValue& value,
		  const YCPValue& arg )
    {
    y2milestone("EvmsAgent::Write(%s, %s)", path->toString().c_str(),
		value.isNull()?"nil":value->toString().c_str());
    YCPBoolean ret(true);

    if (path->length() < 1)
	{
	y2error("Path '%s' has incorrect length", path->toString().c_str());
	ret = false;
	}

    string conf_name = path->component_str(0);

    y2milestone("cmd '%s'", conf_name.c_str());

    if (conf_name == "command")
	{
	YCPMap cmd;
	YCPValue type = YCPNull();
	string CmdLine_Ci;
	string ErrText_Ci;

	if (value.isNull() || !value->isMap())
	    {
	    ErrText_Ci = "invalid evms cmd";
	    y2error("invalid evms cmd: %s", value->toString().c_str());
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
		string container;
		unsigned long stripes = 1;
		unsigned long stripesize = 0;
		YCPValue content = cmd->value(YCPString("name"));
		if( !content.isNull() && content->isString())
		    {
		    name = content->asString()->value();
		    }
		content = cmd->value(YCPString("container"));
		if( !content.isNull() && content->isString())
		    {
		    container = content->asString()->value();
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
		content = cmd->value(YCPString("stripesize"));
		if( !content.isNull() && content->isInteger())
		    {
		    stripesize = content->asInteger()->value();
		    }
		y2milestone("name:%s container:%s size:%ld stripes:%ld",
			     name.c_str(), container.c_str(), size,
			     stripes );
		if( name.length()>0 && container.length()>0 && size>0 )
		    {
		    if( !Evms_pC->CreateLv( name, container, size, stripes,
		                            stripesize ))
			{
			ErrText_Ci = Evms_pC->GetErrorText();
			CmdLine_Ci = Evms_pC->GetCmdLine();
			y2error( "evms error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "evms create_lv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "resize_lv" )
		{
		string name;
		unsigned long size = 0;
		string container;
		YCPValue content = cmd->value(YCPString("name"));
		if( !content.isNull() && content->isString())
		    {
		    name = content->asString()->value();
		    }
		content = cmd->value(YCPString("container"));
		if( !content.isNull() && content->isString())
		    {
		    container = content->asString()->value();
		    }
		content = cmd->value(YCPString("size"));
		if( !content.isNull() && content->isInteger())
		    {
		    size = content->asInteger()->value()/1024;
		    }
		y2milestone("name:%s container:%s new size:%ld",
			     name.c_str(), container.c_str(), size );
		if( name.length()>0 && container.length()>0 && size>0 )
		    {
		    if( !Evms_pC->ChangeLvSize( name, container, size ) )
			{
			ErrText_Ci = Evms_pC->GetErrorText();
			CmdLine_Ci = Evms_pC->GetCmdLine();
			y2error( "evms error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "evms resize_lv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "remove_lv" )
		{
		string name;
		string container;
		YCPValue content = cmd->value(YCPString("name"));
		if( !content.isNull() && content->isString())
		    {
		    name = content->asString()->value();
		    }
		content = cmd->value(YCPString("container"));
		if( !content.isNull() && content->isString())
		    {
		    container = content->asString()->value();
		    }
		y2milestone( "name:%s container:%s", name.c_str(), 
		             container.c_str() );
		if( name.length()>0 && container.length()>0 )
		    {
		    if( !Evms_pC->DeleteLv( name, container ) )
			{
			ErrText_Ci = Evms_pC->GetErrorText();
			CmdLine_Ci = Evms_pC->GetCmdLine();
			y2error( "container error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "evms remove_lv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "create_vg" )
		{
		unsigned long size = 4096;
		string container;
		bool new_media = false;
		list<string> devices;
		YCPValue content = cmd->value(YCPString("container"));
		if( !content.isNull() && content->isString())
		    {
		    container = content->asString()->value();
		    }
		content = cmd->value(YCPString("pesize"));
		if( !content.isNull() && content->isInteger())
		    {
		    size = content->asInteger()->value()/1024;
		    }
		content = cmd->value(YCPString("lvm2"));
		if( !content.isNull() && content->isBoolean())
		    {
		    new_media = content->asBoolean()->value();
		    }
		content = cmd->value(YCPString("devices"));
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
		y2debug("container:%s pesize:%ld new_media:%d devices:%d",
			container.c_str(), size, new_media, devices.size() );
		if( container.length()>0 && size>0 && devices.size()>0 )
		    {
		    if( !Evms_pC->CreateCo( container, size, new_media, devices ) )
			{
			ErrText_Ci = Evms_pC->GetErrorText();
			CmdLine_Ci = Evms_pC->GetCmdLine();
			y2error( "evms error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "evms create_vg invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "remove_vg" )
		{
		string container;
		YCPValue content = cmd->value(YCPString("container"));
		if( !content.isNull() && content->isString())
		    {
		    container = content->asString()->value();
		    }
		y2milestone("container:%s", container.c_str());
		if( container.length()>0 )
		    {
		    if( !Evms_pC->DeleteCo( container ) )
			{
			ErrText_Ci = Evms_pC->GetErrorText();
			CmdLine_Ci = Evms_pC->GetCmdLine();
			y2error( "evms error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "evms remove_vg invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "create_pv" )
		{
		string container;
		string device;
		bool new_meta = false;
		YCPValue content = cmd->value(YCPString("container"));
		if( !content.isNull() && content->isString())
		    {
		    container = content->asString()->value();
		    }
		content = cmd->value(YCPString("device"));
		if( !content.isNull() && content->isString())
		    {
		    device = content->asString()->value();
		    }
		content = cmd->value(YCPString("lvm2"));
		if( !content.isNull() && content->isBoolean())
		    {
		    new_meta = content->asBoolean()->value();
		    }
		y2milestone("container:%s device:%s new_meta:%d",
			     container.c_str(), device.c_str(), new_meta );
		if( device.length()>0 && container.length()>0 )
		    {
		    if( !Evms_pC->ExtendCo( container, device ) )
			{
			ErrText_Ci = Evms_pC->GetErrorText();
			CmdLine_Ci = Evms_pC->GetCmdLine();
			y2error( "evms error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "evms create_pv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else if( type_string == "remove_pv" )
		{
		string container;
		string device;
		YCPValue content = cmd->value(YCPString("container"));
		if( !content.isNull() && content->isString())
		    {
		    container = content->asString()->value();
		    }
		content = cmd->value(YCPString("device"));
		if( !content.isNull() && content->isString())
		    {
		    device = content->asString()->value();
		    }
		y2milestone("container:%s device:%s",
			     container.c_str(), device.c_str() );
		if( device.length()>0 && container.size()>0 )
		    {
		    if( !Evms_pC->ShrinkCo( container, device ) )
			{
			ErrText_Ci = Evms_pC->GetErrorText();
			CmdLine_Ci = Evms_pC->GetCmdLine();
			y2error( "evms error cmd:%s", CmdLine_Ci.c_str() );
			ret = false;
			}
		    }
		else
		    {
		    ErrText_Ci = "evms remove_pv invalid values";
		    y2error( ErrText_Ci.c_str() );
		    ret = false;
		    }
		}
	    else
		{
		ErrText_Ci = "evms invalid cmd";
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
	for( YCPMapIterator I_ii=Err_C.begin(); I_ii!=Err_C.end(); I_ii++ )
	    {
	    Err_C.remove( I_ii.key() );
	    }
	if( !ret->asBoolean()->value() )
	    {
	    Err_C->add( YCPString( "errtxt" ), YCPString( ErrText_Ci ) );
	    if( CmdLine_Ci.length()>0 )
		{
		Err_C->add( YCPString( "cmdline" ), YCPString( CmdLine_Ci ) );
		}
	    }
	}
    else if (conf_name == "init")
	{
	y2milestone( "re-initialize Agent" );
	delete( Evms_pC );
	Evms_pC = new EvmsAccess();
	}
    else
	{
	y2error( "unknown or readonly path %s", path->toString().c_str());
	ret = false;
	}
    return ret;
    }

YCPList EvmsAgent::Dir(const YCPPath& path)
    {
    return YCPList();
    }

