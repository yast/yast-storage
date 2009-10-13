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


/*---------------------------------------------------------------------\
|								       |
|		       __   __	  ____ _____ ____		       |
|		       \ \ / /_ _/ ___|_   _|___ \		       |
|			\ V / _` \___ \ | |   __) |		       |
|			 | | (_| |___) || |  / __/		       |
|			 |_|\__,_|____/ |_| |_____|		       |
|								       |
|				core system			       |
|							 (C) SuSE GmbH |
\----------------------------------------------------------------------/

   File:	StorageCallbacks.h

   Author:	Klaus Kaempf <kkaempf@suse.de>
		Stanislav Visnovsky <visnov@suse.cz>
   Maintainer:  Klaus Kaempf <kkaempf@suse.de>

   Purpose:	Access to the storage callbacks
		Handles StorageCallbacks::function (list_of_arguments) calls
/-*/

#ifndef StorageCallbacks_h
#define StorageCallbacks_h

#include <string>

#include <ycp/YCPBoolean.h>
#include <ycp/YCPValue.h>
#include <ycp/YCPList.h>
#include <ycp/YCPMap.h>
#include <ycp/YCPSymbol.h>
#include <ycp/YCPString.h>
#include <ycp/YCPInteger.h>
#include <ycp/YCPVoid.h>
#include <ycp/YBlock.h>

#include <y2/Y2Namespace.h>

/**
 * A simple class for storage callback access
 */
class StorageCallbacks : public Y2Namespace
{
public:

    // builtin handling
    void registerFunctions ();
    vector<string> _registered_functions;

    // callbacks
    /* TYPEINFO: void(string) */
    YCPValue ProgressBar (const YCPString& func);
    /* TYPEINFO: void(string) */
    YCPValue ShowInstallInfo (const YCPString& func);
    /* TYPEINFO: void(string) */
    YCPValue InfoPopup (const YCPString& func);
    /* TYPEINFO: void(string) */
    YCPValue YesNoPopup (const YCPString& func);
    /* TYPEINFO: void(string) */
    YCPValue PasswordPopup (const YCPString& func);

    /**
     * Constructor.
     */
    StorageCallbacks ();

    /**
     * Destructor.
     */
    virtual ~StorageCallbacks ();

    virtual const string name () const
    {
	return "StorageCallbacks";
    }

    virtual const string filename () const
    {
	return "StorageCallbacks";
    }

    virtual string toString () const
    {
	return "// not possible toString";
    }

    virtual YCPValue evaluate (bool cse = false)
    {
	if (cse) return YCPNull ();
	else return YCPVoid ();
    }

    virtual Y2Function* createFunctionCall (const string name, constFunctionTypePtr type);

    static StorageCallbacks* instance ();

private:

    static StorageCallbacks* current_instance;

};

#endif // StorageCallbacks_h
