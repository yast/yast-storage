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

   File:       Y2CCStorageCallbacks.h

   Author:     Stanislav Visnovsky <visnov@suse.de>
   Maintainer: Stanislav Visnovsky <visnov@suse.de>

/-*/
// -*- c++ -*-

/*
 * Component Creator that executes access to packagemanager
 *
 * Author: Author:     Stanislav Visnovsky <visnov@suse.de>
 */

#ifndef Y2CCStorageCallbacks_h
#define Y2CCStorageCallbacks_h

#include <y2/Y2ComponentCreator.h>

class Y2Component;

class Y2CCStorageCallbacks : public Y2ComponentCreator
{
    
public:
    /**
     * Creates a StorageCallbacks component creator.
     */
    Y2CCStorageCallbacks() : Y2ComponentCreator(Y2ComponentBroker::BUILTIN) {}

    /**
     * Tries to create a StorageCallbacks module
     */
    virtual Y2Component *createInLevel(const char *name, int level, int current_level) const;

    virtual bool isServerCreator() const;
    
    /**
     * We provide the StorageCallbacks namespace
     */
    virtual  Y2Component *provideNamespace(const char *name);
};


#endif // Y2CCStorageCallbacks_h
