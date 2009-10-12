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


#ifndef PROC_MOUNTS_H
#define PROC_MOUNTS_H

#include <string>
#include <list>
#include <map>

#include "y2storage/EtcFstab.h"

namespace storage
{
class Storage;

class ProcMounts 
    {
    public:
	ProcMounts( Storage * const s );
	string getMount( const string& Dev ) const;
	string getMount( const std::list<string>& dl ) const;
	std::map<string,string> allMounts() const;
	void getEntries( std::list<FstabEntry>& l ) const;
    protected:
	std::map<string,FstabEntry> co;
    };

}

#endif
