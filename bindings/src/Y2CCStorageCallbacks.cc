/*
 * Copyright (c) 2012 Novell, Inc.
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
|                                                                      |
|                      __   __    ____ _____ ____                      |
|                      \ \ / /_ _/ ___|_   _|___ \                     |
|                       \ V / _` \___ \ | |   __) |                    |
|                        | | (_| |___) || |  / __/                     |
|                        |_|\__,_|____/ |_| |_____|                    |
|                                                                      |
|                               core system                            |
|                                                        (C) SuSE GmbH |
\----------------------------------------------------------------------/

   File:       Y2CCStorageCallbacks.cc

   Author:     Stanislav Visnovsky <visnov@suse.cz>
   Maintainer: Stanislav Visnovsky <visnov@suse.cz>

/-*/
/*
 * Component Creator that executes access to the storage library callbacks
 *
 * Author: Stanislav Visnovsky <visnov@suse.cz>
 */


#define y2log_component libstorage

#include <ycp/y2log.h>
#include <y2/Y2Component.h>
#include "Y2CCStorageCallbacks.h"
#include "Y2StorageCallbacksComponent.h"

Y2Component *Y2CCStorageCallbacks::createInLevel(const char *name, int level, int) const
{
    if (strcmp (name, "StorageCallbacks") == 0)
    {
	return Y2StorageCallbacksComponent::instance ();
    }
    else
    {
	return NULL;
    }
}

bool Y2CCStorageCallbacks::isServerCreator() const
{
    return false;
}

Y2Component* Y2CCStorageCallbacks::provideNamespace(const char* name)
{
    if (strcmp (name, "StorageCallbacks") == 0)
    {
	return Y2StorageCallbacksComponent::instance ();
    }
    else
    {
	return NULL;
    }
}

// Create global variable to register this component creator

Y2CCStorageCallbacks g_y2ccStorageCallbacks;
