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


#define y2log_component libstorage

#include <y2util/y2log.h>
#include <y2/Y2Namespace.h>
#include <y2/Y2Component.h>
#include <y2/Y2ComponentCreator.h>

#include "Y2StorageCallbacksComponent.h"

#include "StorageCallbacks.h"

Y2Namespace *Y2StorageCallbacksComponent::import (const char* name)
{
    // FIXME: for internal components, we should track changes in symbol numbering
    if ( strcmp (name, "StorageCallbacks") == 0)
    {
	return StorageCallbacks::instance ();
    }
	
    return NULL;
}

Y2StorageCallbacksComponent* Y2StorageCallbacksComponent::m_instance = NULL;

Y2StorageCallbacksComponent* Y2StorageCallbacksComponent::instance ()
{
    if (m_instance == NULL)
    {
        m_instance = new Y2StorageCallbacksComponent ();
    }

    return m_instance;
}

