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


#ifndef PROC_PART_H
#define PROC_PART_H

#include <string>
#include <list>
#include <map>

#include "y2storage/AsciiFile.h"

namespace storage
{

class ProcPart : public AsciiFile
    {
    public:
	ProcPart();
	bool getInfo( const string& Dev, unsigned long long& SizeK, 
	              unsigned long& Major, unsigned long& Minor ) const;
	bool getSize( const string& Dev, unsigned long long& SizeK ) const;
	std::list<string> getMatchingEntries( const string& regexp ) const;
    protected:
	static string devName( const string& Dev );
	std::map<string,int> co;
    };

}

#endif
