/*
 * Copyright (c) [2004-2009] Novell, Inc.
 *
 * All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of version 2 of the GNU General Public License as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, contact Novell, Inc.
 *
 * To contact Novell about this file by physical or electronic mail, you may
 * find current contact information at www.novell.com.
 */

// Maintainer: fehr@suse.de
/*
  Textdomain    "storage"
*/

#include <sstream>

#include "y2storage/AppUtil.h"
#include "y2storage/Regex.h"
#include "y2storage/StorageTmpl.h"
#include "y2storage/ProcPart.h"

using namespace std;
using namespace storage;

ProcPart::ProcPart() : AsciiFile( "/proc/partitions" )
    {
    y2mil( "numLines " << numLines() );
    for( unsigned i=0; i<numLines(); i++ )
	{
	y2mil( "line " << (i+1) << " is \"" << (*this)[i] << "\"" );
	string tmp = extractNthWord( 3, (*this)[i] );
	if( !tmp.empty() && tmp!="name" )
	    {
	    co[tmp] = i;
	    }
	}
    }

bool 
ProcPart::getInfo( const string& Dev, unsigned long long& SizeK,
		   unsigned long& Major, unsigned long& Minor ) const
    {
    bool ret = false;
    map<string,int>::const_iterator i = co.find( devName(Dev) );
    if( i != co.end() )
	{
	extractNthWord( 0, (*this)[i->second] ) >> Major;
	extractNthWord( 1, (*this)[i->second] ) >> Minor;
	extractNthWord( 2, (*this)[i->second] ) >> SizeK;
	ret = true;
	}
    return( ret );
    }


    bool
    ProcPart::findDevice(const string& device) const
    {
	return co.find(devName(device)) != co.end();
    }


bool 
ProcPart::getSize( const string& Dev, unsigned long long& SizeK ) const
    {
    bool ret = false;
    map<string,int>::const_iterator i = co.find( devName(Dev) );
    if( i != co.end() )
	{
	extractNthWord( 2, (*this)[i->second] ) >> SizeK;
	ret = true;
	}
    y2mil( "dev:" << Dev << " ret:" << ret << " Size:" << (ret?SizeK:0) );
    return( ret );
    }

string 
ProcPart::devName( const string& Dev )
    {
    return( undevDevice( Dev ));
    }

list<string>  
ProcPart::getMatchingEntries( const string& regexp ) const
    {
    Regex reg( "^" + regexp + "$" );
    list<string> ret;
    for( map<string,int>::const_iterator i=co.begin(); i!=co.end(); i++ )
	{
	if( reg.match( i->first ))
	    {
	    ret.push_back( i->first );
	    }
	}
    return( ret );
    }

