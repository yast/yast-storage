// Maintainer: fehr@suse.de

#include <sstream>
#include <set>
#include <ycp/YCPParser.h>
#include <ycp/y2log.h>

#include "FdiskAgent.h"
#include "FdiskAcc.h"
#include "PartedAcc.h"

using namespace std;

#if defined(__sparc__)
#define MINUS_1
#define PLUS_1
#else
#define MINUS_1 -1
#define PLUS_1 +1
#endif

FdiskAgent::FdiskAgent()
{
    y2debug( "Constructor FdiskAgent" );
}


FdiskAgent::~FdiskAgent()
{
    y2debug( "Destructor FdiskAgent" );
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
FdiskAgent::Read(const YCPPath& path, const YCPValue& arg)
{
  YCPValue ret = YCPVoid();
  bool use_parted = false;
  if( !arg.isNull() && arg->isBoolean() && arg->asBoolean()->value() )
      use_parted = true;

  y2milestone("FdiskAgent::Read(%s, %s) parted:%d", path->toString().c_str(),
	      arg.isNull()?"nil":arg->toString().c_str(), use_parted );

  if (path->length() < 2) {
      y2error("Path '%s' has incorrect length", path->toString().c_str());
      return YCPVoid();
  }

  int i = 0;
  string device_name = "";

  while (i < path->length()-1) {
    device_name += "/" + path->component_str(i);
    i = i + 1;
  }

  string conf_name = path->component_str(i);
  string device = string("/dev") + device_name;

  y2milestone("device '%s', cmd '%s'", device.c_str(), conf_name.c_str());

  DiskAccess *fdisk_cmd = NULL;

  if (conf_name == "partitions")
      {
      if( use_parted )
	fdisk_cmd = new PartedAccess( device, true );
      else
	fdisk_cmd = new FdiskAccess( device, true );
      }
  else
      fdisk_cmd = new DiskAccess( device );

  if (conf_name == "partitions")
    {
      // Return the partition table
      YCPList partitions;
      vector<PartInfo> &part_info = fdisk_cmd->Partitions();
      for (vector<PartInfo>::iterator entry = part_info.begin();
	   entry != part_info.end(); entry++)
	{
	  YCPMap part_entry;
	  // XXX
#if defined(__sparc__)
	  // On sparc, we have only primary partitions
          YCPSymbol ptype("primary", true);
#else
	  YCPSymbol ptype(entry->PType_e == PAR_TYPE_EXTENDED ? "extended"
			  : entry->Num_i >= 5 ? "logical" : "primary", true);
#endif
	  part_entry->add (YCPString ("type"), ptype);
	  part_entry->add (YCPString ("nr"), YCPInteger (entry->Num_i));
	  part_entry->add (YCPString ("fsid"), YCPInteger (entry->Id_i));
	  part_entry->add (YCPString ("fstype"), YCPString (entry->Info_C));
	  YCPList region;
	  region->add (YCPInteger (entry->Start_i MINUS_1));
	  region->add (YCPInteger (entry->End_i PLUS_1 - entry->Start_i));
	  part_entry->add (YCPString ("region"), region);
	  partitions->add (part_entry);
	}
      ret = partitions;
    }
  else if (conf_name == "bytes_per_unit")
    {
      y2debug("bytes_per_unit");
      ret = YCPInteger (fdisk_cmd->CylinderToKb (1) * 1024LL);
    }
  else if (conf_name == "disk_size")
    {
      ret = YCPInteger (fdisk_cmd->NumCylinder());
    }
  else if (conf_name == "max_primary")
    {
      ret = YCPInteger (fdisk_cmd->PrimaryMax());
    }
  else
    {
      y2error("unknown command in path '%s'", path->toString().c_str());
    }
  delete fdisk_cmd;
  return( ret );
}

struct Created_partition
{
  YCPMap entry;
  int nr;
  PartitionType type;
  int start;
  int length;
  int fsid;
  friend bool operator< (const Created_partition &x, const Created_partition &y)
  { return x.nr < y.nr; }
};

namespace std
{

template<> struct std::less<Created_partition>
{
  bool operator() (const Created_partition &x, const Created_partition &y)
  { return x < y; }
};
}
typedef set<Created_partition, std::less<Created_partition> > CPart_set;


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
FdiskAgent::Write(const YCPPath& path, const YCPValue& value, const YCPValue& arg)
{
  y2milestone("FdiskAgent::Write(%s, %s, %s)", path->toString().c_str(),
	      value.isNull()?"nil":value->toString().c_str(),
	      arg.isNull()?"nil":arg->toString().c_str());

  bool use_parted = false;
  if( !arg.isNull() && arg->isBoolean() && arg->asBoolean()->value() )
      use_parted = true;

  if (path->length() < 2)
    {
      y2error("Path '%s' has incorrect length", path->toString().c_str());
      return YCPVoid();
    }

  int i = 0;
  string device_name = "";

  while (i < path->length()-1) {
    device_name += "/" + path->component_str(i);
    i = i + 1;
  }

  string conf_name = path->component_str(i);

  y2milestone("device '%s', cmd '%s'", device_name.c_str(), conf_name.c_str());

  if (conf_name == "partitions")
    {
      // Write new partition table
      if (!value->isList())
	{
	  y2error("invalid partition table: %s", value->toString().c_str());
	  return YCPBoolean(false);
	}

      YCPList partitions = value->asList();

      // Do some consistency checking
      for (int i = 0; i < partitions->size(); i++)
	{
	  if (partitions->value (i)->isMap())
	    {
	      YCPMap pentry = partitions->value (i)->asMap();
	      YCPValue pnr = pentry->value (YCPString ("nr"));
	      if (!pnr.isNull() && pnr->isInteger())
		continue;
	    }
	  y2error("invalid partition table: %s", value->toString().c_str());
	  return YCPBoolean(false);
	}

      // Look for partitions to be deleted
      set<int> to_delete;
      for (int i = 0; i < partitions->size(); i++)
	{
	  YCPMap pentry = partitions->value (i)->asMap ();
	  YCPValue do_delete = pentry->value (YCPString ("delete"));
	  if (!do_delete.isNull() && do_delete->isBoolean ()
	      && do_delete->asBoolean ()->value ())
	    {
	      // Delete this partition
	      YCPValue pnr = pentry->value (YCPString ("nr"));
	      to_delete.insert(pnr->asInteger ()->value ());
	    }
	}

      // Look for partitions to be created.
      CPart_set to_create;
      for (int i = 0; i < partitions->size(); i++)
	{
	  YCPMap pentry = partitions->value (i)->asMap ();
	  y2debug("looking at %s", pentry->toString().c_str());
	  YCPValue do_create = pentry->value (YCPString ("create"));
	  if (!do_create.isNull() && do_create->isBoolean()
	      && do_create->asBoolean()->value())
	    {
	      // Create this partition
	      YCPValue ptype = pentry->value (YCPString ("type"));
	      YCPValue pnr = pentry->value (YCPString ("nr"));
	      YCPValue pfsid = pentry->value (YCPString ("fsid"));
	      YCPValue pregion = pentry->value (YCPString ("region"));
	      if (ptype.isNull() || !ptype->isSymbol()
		  || pfsid.isNull() || !pfsid->isInteger()
		  || pregion.isNull() || !pregion->isList()
		  || pregion->asList()->size() != 2
		  || !pregion->asList()->value(0)->isInteger()
		  || !pregion->asList()->value(1)->isInteger())
		{
		invalid:
		  y2error( "invalid partition table: %s",
			   value->toString().c_str());
		  return YCPBoolean(false);
		}
	      Created_partition cpart;
	      cpart.entry = pentry;
	      if (ptype->asSymbol()->symbol() == "primary")
		cpart.type = PAR_TYPE_PRIMARY;
	      else if (ptype->asSymbol()->symbol() == "extended")
		cpart.type = PAR_TYPE_EXTENDED;
	      else if (ptype->asSymbol()->symbol() == "logical")
		cpart.type = PAR_TYPE_LOGICAL;
	      else
		goto invalid;

	      cpart.nr = pnr->asInteger()->value();
	      cpart.start = pregion->asList()->value(0)->asInteger()->value();
	      cpart.length = pregion->asList()->value(1)->asInteger()->value();
	      cpart.fsid = pfsid->asInteger()->value();

	      to_create.insert (cpart);
	    }
	}

      if( to_delete.begin() != to_delete.end() ||
          to_create.begin() != to_create.end() )
	  {
	  DiskAccess *fdisk_cmd = NULL;
	  string device = string("/dev") + device_name;

	  if( use_parted )
	    fdisk_cmd = new PartedAccess( device, false );
	  else
	    fdisk_cmd = new FdiskAccess( device, false );

	  // Now actually delete the parttitions, starting from the last
	  for (set<int>::reverse_iterator part_nr = to_delete.rbegin ();
	       part_nr != to_delete.rend (); ++part_nr)
	    {
	      y2milestone("deleting partition %d", *part_nr);
	      fdisk_cmd->Delete (*part_nr);
	    }

	  // Now create the new partitions, with increasing partition number.
	  for (CPart_set::iterator cpart = to_create.begin ();
	       cpart != to_create.end (); ++cpart)
	    {
	      ostringstream buffer;
	      buffer << cpart->start PLUS_1 << ends;
	      string start_string = buffer.str();
	      buffer.seekp(0, ios::beg);
	      buffer << cpart->start + cpart->length << ends;
	      string end_string = buffer.str();

	      y2milestone( "creating partition: type %d, nr %d, start %s, end %s",
			   cpart->type, cpart->nr, start_string.c_str(),
			   end_string.c_str());
	      y2milestone( "setting type of partition to %x", cpart->fsid);
	      if (!fdisk_cmd->NewPartition (cpart->type, cpart->nr, start_string,
					   end_string, cpart->fsid ))
		{
		  y2error("fdisk failed for %s", cpart->entry->toString().c_str());
		  return YCPBoolean(false);
		}

	    }
	  if (fdisk_cmd->Changed())
	    {
	    bool Ret_bi;
	    Ret_bi = !fdisk_cmd->WritePartitionTable();
	    return(YCPBoolean(Ret_bi));
	    }
	  delete( fdisk_cmd );
	  }

      return YCPBoolean (true);
    }
  else if (conf_name == "command")
    {
    bool ret = false;
    YCPValue type = YCPNull();
    YCPMap cmd;

      // Write new partition table
      if (!value->isMap())
	{
	y2error("invalid fdisk cmd: %s", value->toString().c_str());
	ret = false;
	}
      else
	{
	cmd = value->asMap();
	type = cmd->value(YCPString("type"));
	}

      if( !type.isNull() && type->isString() )
	{
	string type_string = type->asString()->value();
	y2milestone("cmd %s", type_string.c_str());
	if( type_string == "change_id" )
	    {
	    int id = -1;
	    int part_nr = -1;
	    YCPValue content = cmd->value(YCPString("id"));
	    if( !content.isNull() && content->isInteger())
		{
		id = content->asInteger()->value();
		}
	    content = cmd->value(YCPString("nr"));
	    if( !content.isNull() && content->isInteger())
		{
		part_nr = content->asInteger()->value();
		}
	    y2debug("part:%d id:%x", part_nr, id );
	    if( part_nr>0 && id>=0 )
		{
		string device = string("/dev") + device_name;
		DiskAccess *fdisk_cmd = NULL;

	        if( use_parted )
		    fdisk_cmd = new PartedAccess( device, false );
		else
		    fdisk_cmd = new FdiskAccess( device, false );

		fdisk_cmd->SetType( part_nr, id );
		if (fdisk_cmd->Changed())
		    fdisk_cmd->WritePartitionTable();
		ret = true;
		delete fdisk_cmd;
		}
	    }
	else if( type_string == "resize" )
	    {
	    int new_cyl_cnt = -1;
	    int part_nr = -1;
	    YCPValue content = cmd->value(YCPString("new_cyl_cnt"));
	    if( !content.isNull() && content->isInteger())
		{
		new_cyl_cnt = content->asInteger()->value();
		}
	    content = cmd->value(YCPString("nr"));
	    if( !content.isNull() && content->isInteger())
		{
		part_nr = content->asInteger()->value();
		}
	    y2debug("part:%d last_cyl:%d", part_nr, new_cyl_cnt );
	    if( part_nr>0 && new_cyl_cnt>=0 )
		{
		string device = string("/dev") + device_name;
		PartedAccess fdisk_cmd( device, false );

		ret = fdisk_cmd.Resize( part_nr, new_cyl_cnt );
		}
	    }
	else
	    {
	    y2error( "fdisk invalid cmd" );
	    ret = false;
	    }
	}

      return YCPBoolean (ret);
    }
  else
    {
      y2error("unknown or readonly path %s", path->toString().c_str());
    }
  return YCPVoid();
}

YCPValue FdiskAgent::Dir(const YCPPath& path)
{
  return YCPList();
}

