/*
 * File: MdPart.cc
 *
 * Implementation of MdPart class which represents single partition on MD
 * Device (RAID Volume).
 *
 * Copyright (c) 2009, Intel Corporation.
 * Copyright (c) 2009 Novell, Inc.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St - Fifth Floor, Boston, MA 02110-1301 USA.
 */

/*
  Textdomain    "storage"
*/

#include <sstream>

#include "y2storage/MdPart.h"
#include "y2storage/MdPartCo.h"
#include "y2storage/SystemCmd.h"
#include "y2storage/ProcPart.h"
#include "y2storage/AppUtil.h"
#include "y2storage/Storage.h"


namespace storage
{
    using namespace std;


MdPart::MdPart(const MdPartCo& d, unsigned nr, Partition* pa) : Volume( d, nr, 0 )
{
    init( d.numToName(nr) );
    numeric = true;
    num = nr;
    p = pa;
    if( pa )
      {
        setSize( pa->sizeK() );
      }
    y2mil("constructed MdPart " << dev << " on MdPartCo : " << cont->name());
}

MdPart::MdPart(const MdPartCo& d, const MdPart& rhs)
    : Volume( d, 0, 0 )
{
    y2deb("constructed MdPart by copy constructor from " << rhs.dev);
    *this = rhs;
}


MdPart::~MdPart()
{
    y2deb("destructed MdPart " << dev);
}

void MdPart::init( const string& name )
    {
    p = NULL;
    dev = "/dev/" + name;
    string::size_type pos =  name.find_last_of( "/" );
    if( pos!=string::npos )
      {
        nm = name.substr( pos+1 );
      }
    else
      {
        nm = name;
      }
    }

const MdPartCo* MdPart::co() const
    {
    return(dynamic_cast<const storage::MdPartCo*>(cont));
    }

void MdPart::updateName()
    {
    if( p && p->nr() != num )
        {
        num = p->nr();
        nm = co()->numToName(num);
        dev = "/dev/" + nm;
        }
    }

void MdPart::updateMinor()
    {
    unsigned long mj=mjr;
    unsigned long mi=mnr;
    getMajorMinor( dev, mj, mi );
    if( mi!=mnr || mj!=mjr )
        {
        mnr = mi;
        mjr = mj;
        }
    }

void MdPart::updateSize()
    {
    if( p )
        {
        orig_size_k = p->origSizeK();
        size_k = p->sizeK();
        }
    }

void MdPart::updateSize( ProcPart& pp )
    {
    unsigned long long si = 0;
    updateSize();
    //In case of extended partition /proc/partition contains size 1.
    if( p && p->type() != storage::EXTENDED )
      {
      if( mjr>0 && pp.getSize( nm, si ))
        {
          setSize( si );
        }
      }
    }

void MdPart::addUdevData()
    {
    addAltUdevId( num );
    }
//TODO: Is it OK? Check it
static string udevCompleteIdPath( const string& s, unsigned nr )
    {
    return( "/dev/disk/by-id/" + s + "-part" + decString(nr) );
    }


void
MdPart::addAltUdevId( unsigned num )
{
    list<string>::iterator i = alt_names.begin();
    while( i!=alt_names.end() )
        {
        if( i->find( "/by-id/" ) != string::npos )
            i = alt_names.erase( i );
        else
            ++i;
        }
    list<string>::const_iterator j = co()->udevId().begin();
    while( j!=co()->udevId().end() )
        {
        alt_names.push_back( udevCompleteIdPath( *j, num ));
        ++j;
        }
    mount_by = orig_mount_by = defaultMountBy();
}


const std::list<string>
MdPart::udevId() const
{
    list<string> ret;
    for (list<string>::const_iterator i = alt_names.begin();
         i != alt_names.end(); i++)
    {
        if (i->find("/by-id/") != string::npos)
            ret.push_back(*i);
    }
    return ret;
}


void MdPart::getCommitActions( std::list<storage::commitAction*>& l ) const
    {
    unsigned s = l.size();
    Volume::getCommitActions(l);
    if( p )
        {
        if( s==l.size() && Partition::toChangeId( *p ) )
            l.push_back( new commitAction( INCREASE, cont->staticType(),
                                           setTypeText(false), this, false ));
        }
    }

string MdPart::setTypeText( bool doing ) const
    {
    string txt;
    string d = dev;
    if( doing )
        {
        // displayed text during action, %1$s is replaced by partition name (e.g. pdc_dabaheedj1),
        // %2$s is replaced by hexadecimal number (e.g. 8E)
        txt = sformat( _("Setting type of partition %1$s to %2$X"),
                      d.c_str(), id() );
        }
    else
        {
        // displayed text before action, %1$s is replaced by partition name (e.g. pdc_dabaheedj1),
        // %2$s is replaced by hexadecimal number (e.g. 8E)
        txt = sformat( _("Set type of partition %1$s to %2$X"),
                      d.c_str(), id() );
        }
    return( txt );
    }

void MdPart::getInfo( MdPartInfo& tinfo ) const
    {
    ((Volume*)this)->getInfo( info.v );
    if( p )
        p->getInfo( info.p );
    info.part = p!=NULL;
    tinfo = info;
    }


std::ostream& operator<< (std::ostream& s, const MdPart &p )
    {
    s << "MdPart: ";
    s << *(Volume*)&p;
    return( s );
    }

bool MdPart::equalContent( const MdPart& rhs ) const
    {
    return( Volume::equalContent(rhs) );
    }

void MdPart::logDifference( const MdPart& rhs ) const
{
   string log = Volume::logDifference(rhs);
   y2mil(log);
}


MdPart& MdPart::operator=(const MdPart& rhs)
{
    y2deb("operator= from " << rhs.nm);
    *((Volume*)this) = rhs;
    return *this;
}


void MdPart::getPartitionInfo(storage::PartitionInfo& pinfo)
{
  ((Volume*)this)->getInfo( pinfo.v );
  if( p )
    {
      PartitionAddInfo info;
      p->getInfo( info );
      pinfo = info;
    }

}


}
