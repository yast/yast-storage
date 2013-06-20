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

   File:	StorageCallbacks.cc

   Author:	Klaus Kaempf <kkaempf@suse.de>
		Stanislav Visnovsky <visnov@suse.cz>
   Maintainer:  Klaus Kaempf <kkaempf@suse.de>
   Namespace:   StorageCallbacks
   Summary:	StorageCallbacks constructor, destructor and call handling

/-*/

#define y2log_component "libstorage"

#include <algorithm>

#include <ycp/y2log.h>
#include <ycp/YExpression.h>
#include <ycp/YBlock.h>
#include "StorageCallbacks.h"

#include <ycp/YCPInteger.h>
#include <ycp/YCPString.h>
#include <ycp/YCPBoolean.h>
#include <ycp/YCPMap.h>
#include <ycp/YCPVoid.h>

#include <y2/Y2Component.h>
#include <y2/Y2ComponentBroker.h>

#include <storage/StorageInterface.h>

namespace storage
{
    // workaround for broken YCP bindings
    extern CallbackProgressBar progress_bar_cb_ycp;
    extern CallbackShowInstallInfo install_info_cb_ycp;
    extern CallbackInfoPopup info_popup_cb_ycp;
    extern CallbackYesNoPopup yesno_popup_cb_ycp; 
    extern CallbackCommitErrorPopup commit_error_popup_cb_ycp;
    extern CallbackPasswordPopup password_popup_cb_ycp;
}


class Y2StorageCallbackFunction : public Y2Function
{
    unsigned int m_position;
    StorageCallbacks* m_instance;
    YCPValue m_param1;
    YCPValue m_param2;
    YCPValue m_param3;
    YCPValue m_param4;

public:

    Y2StorageCallbackFunction (StorageCallbacks* instance, unsigned int pos);
    bool attachParameter (const YCPValue& arg, const int position);
    constTypePtr wantedParameterType () const;
    bool appendParameter (const YCPValue& arg);
    bool finishParameters ();
    YCPValue evaluateCall ();
    bool reset ();
    string name () const;
};


Y2StorageCallbackFunction::Y2StorageCallbackFunction (StorageCallbacks* instance,
						      unsigned int pos)
    : m_position (pos),
      m_instance (instance),
      m_param1 ( YCPNull () ),
      m_param2 ( YCPNull () ),
      m_param3 ( YCPNull () ),
      m_param4 ( YCPNull () )
{
}

bool Y2StorageCallbackFunction::attachParameter (const YCPValue& arg,
						 const int position)
{
    switch (position)
    {
	case 0: m_param1 = arg; break;
	case 1: m_param2 = arg; break;
	case 2: m_param3 = arg; break;
	case 3: m_param4 = arg; break;
	default: return false;
    }

    return true;
}


constTypePtr Y2StorageCallbackFunction::wantedParameterType () const
{
    y2internal ("wantedParameterType not implemented");
    return Type::Unspec;
}

bool Y2StorageCallbackFunction::appendParameter (const YCPValue& arg)
{
    if (m_param1.isNull ())
    {
	m_param1 = arg;
	return true;
    }
    else if (m_param2.isNull ())
    {
	m_param2 = arg;
	return true;
    }
    else if (m_param3.isNull ())
    {
	m_param3 = arg;
	return true;
    }
    else if (m_param4.isNull ())
    {
	m_param4 = arg;
	return true;
    }
    y2internal ("appendParameter > 3 not implemented");
    return false;
}

bool Y2StorageCallbackFunction::finishParameters ()
{
    return true;
}

YCPValue Y2StorageCallbackFunction::evaluateCall ()
{
    switch (m_position) {
#include "StorageCallbacksBuiltinCalls.h"
    }

    return YCPNull ();
}

bool Y2StorageCallbackFunction::reset ()
{
    m_param1 = YCPNull ();
    m_param2 = YCPNull ();
    m_param3 = YCPNull ();
    m_param4 = YCPNull ();

    return true;
}

string Y2StorageCallbackFunction::name () const
{
    return m_instance->name();
}

/**
 * Constructor.
 */
StorageCallbacks::StorageCallbacks ()
{
    registerFunctions ();
    registerLogHandlers();
}

/**
 * Destructor.
 */
StorageCallbacks::~StorageCallbacks ()
{
}

StorageCallbacks* StorageCallbacks::current_instance = NULL;

StorageCallbacks* StorageCallbacks::instance ()
{
    if (current_instance == NULL)
    {
	current_instance = new StorageCallbacks ();
    }

    return current_instance;
}

Y2Function* StorageCallbacks::createFunctionCall (const string name,
						  constFunctionTypePtr type)
{
    vector<string>::iterator it = find (_registered_functions.begin (),
					_registered_functions.end (), name);
    if (it == _registered_functions.end ())
    {
	y2error ("No such function %s", name.c_str ());
	return NULL;
    }

    return new Y2StorageCallbackFunction (this, it - _registered_functions.begin ());
}

void StorageCallbacks::registerFunctions()
{
#include "StorageCallbacksBuiltinTable.h"
}

static Y2Function* progress_bar = NULL;
static Y2Function* show_install_info = NULL;
static Y2Function* info_popup = NULL;
static Y2Function* yesno_popup = NULL;
static Y2Function* commit_error_popup = NULL;
static Y2Function* password_popup = NULL;

void progress_bar_callback( const string& id, unsigned cur, unsigned max )
{
    if (progress_bar)
    {
	progress_bar->reset ();
	progress_bar->appendParameter ( YCPString (id) );
	progress_bar->appendParameter ( YCPInteger (cur) );
	progress_bar->appendParameter ( YCPInteger (max) );
	progress_bar->finishParameters ();
	progress_bar->evaluateCall ();
    }
}

void show_install_info_callback( const string& id )
{
    if (show_install_info)
    {
	show_install_info->reset ();
	show_install_info->appendParameter ( YCPString (id) );
	show_install_info->finishParameters ();
	show_install_info->evaluateCall ();
    }
}

void info_popup_callback( const string& text )
{
    if (info_popup)
    {
	info_popup->reset ();
	info_popup->appendParameter ( YCPString (text) );
	info_popup->finishParameters ();
	info_popup->evaluateCall ();
    }
}

bool yesno_popup_callback( const string& text )
{
    bool ret = false;

    if (yesno_popup)
    {
	yesno_popup->reset ();
	yesno_popup->appendParameter ( YCPString (text) );
	yesno_popup->finishParameters ();

	YCPValue tmp = yesno_popup->evaluateCall ();
	if (tmp->isBoolean())
            ret = tmp->asBoolean()->value();
    }

    return ret;
}


bool commit_error_popup_callback(int error, const string& last_action, const string& extended_message)
{
    bool ret = false;

    if (commit_error_popup)
    {
	commit_error_popup->reset();
	commit_error_popup->appendParameter(YCPInteger(error));
	commit_error_popup->appendParameter(YCPString(last_action));
	commit_error_popup->appendParameter(YCPString(extended_message));
	commit_error_popup->finishParameters();

	YCPValue tmp = commit_error_popup->evaluateCall();
	if (tmp->isBoolean())
            ret = tmp->asBoolean()->value();
    }

    return ret;
}


bool password_popup_callback(const string& device, int attempts, string& password)
{
    bool ret = false;

    if (password_popup)
    {
	password_popup->reset();
	password_popup->appendParameter(YCPString(device));
	password_popup->appendParameter(YCPInteger(attempts));
	password_popup->appendParameter(YCPString(password));
	password_popup->finishParameters();

	YCPValue tmp1 = password_popup->evaluateCall();
	YCPList tmp2 = tmp1->asList();

	ret = tmp2->value(0)->asBoolean()->value();
	password = tmp2->value(1)->asString()->value();	
    }

    return ret;
}


YCPValue
StorageCallbacks::ProgressBar (const YCPString & callback)
{
    string name_r = callback->value ();

    y2debug ("Registering callback %s", name_r.c_str ());
    string::size_type colonpos = name_r.find("::");

    if ( colonpos == string::npos )
    {
	ycp2error ("Specify namespace and the fuction name for a callback");
	return YCPVoid ();
    }

    string module = name_r.substr ( 0, colonpos );
    string name = name_r.substr ( colonpos + 2 );

    Y2Component *c = Y2ComponentBroker::getNamespaceComponent (module.c_str ());
    if (c == NULL)
    {
	ycp2error ("No component can provide namespace %s for a callback of %s",
		   module.c_str (), name.c_str ());
	return YCPVoid ();
    }

    Y2Namespace *ns = c->import (module.c_str ());
    if (ns == NULL)
    {
	y2error ("No namespace %s for a callback of %s", module.c_str (),
		 name.c_str ());
	return YCPVoid ();
    }

    progress_bar = ns->createFunctionCall (name, Type::Unspec);
    if (progress_bar == NULL)
    {
	ycp2error ("Cannot find function %s in module %s as a callback",
		   name.c_str(), module.c_str () );
	return YCPVoid ();
    }

    storage::progress_bar_cb_ycp = progress_bar_callback;

    return YCPVoid ();
}

YCPValue
StorageCallbacks::ShowInstallInfo (const YCPString & callback)
{
    string name_r = callback->value ();

    y2debug ("Registering callback %s", name_r.c_str ());
    string::size_type colonpos = name_r.find("::");

    if ( colonpos == string::npos )
    {
	ycp2error ("Specify namespace and the fuction name for a callback");
	return YCPVoid ();
    }

    string module = name_r.substr ( 0, colonpos );
    string name = name_r.substr ( colonpos + 2 );

    Y2Component *c = Y2ComponentBroker::getNamespaceComponent (module.c_str ());
    if (c == NULL)
    {
	ycp2error ("No component can provide namespace %s for a callback of %s",
		   module.c_str (), name.c_str ());
	return YCPVoid ();
    }

    Y2Namespace *ns = c->import (module.c_str ());
    if (ns == NULL)
    {
	y2error ("No namespace %s for a callback of %s", module.c_str (),
		 name.c_str ());
	return YCPVoid ();
    }

    show_install_info = ns->createFunctionCall (name, Type::Unspec);
    if (show_install_info == NULL)
    {
	ycp2error ("Cannot find function %s in module %s as a callback",
		   name.c_str(), module.c_str () );
	return YCPVoid ();
    }

    storage::install_info_cb_ycp = show_install_info_callback;

    return YCPVoid ();
}

YCPValue
StorageCallbacks::InfoPopup (const YCPString & callback)
{
    string name_r = callback->value ();

    y2debug ("Registering callback %s", name_r.c_str ());
    string::size_type colonpos = name_r.find("::");

    if ( colonpos == string::npos )
    {
	ycp2error ("Specify namespace and the fuction name for a callback");
	return YCPVoid ();
    }

    string module = name_r.substr ( 0, colonpos );
    string name = name_r.substr ( colonpos + 2 );

    Y2Component *c = Y2ComponentBroker::getNamespaceComponent (module.c_str ());
    if (c == NULL)
    {
	ycp2error ("No component can provide namespace %s for a callback of %s",
		   module.c_str (), name.c_str ());
	return YCPVoid ();
    }

    Y2Namespace *ns = c->import (module.c_str ());
    if (ns == NULL)
    {
	y2error ("No namespace %s for a callback of %s", module.c_str (),
		 name.c_str ());
	return YCPVoid ();
    }

    info_popup = ns->createFunctionCall (name, Type::Unspec);
    if (info_popup == NULL)
    {
	ycp2error ("Cannot find function %s in module %s as a callback",
		   name.c_str(), module.c_str () );
	return YCPVoid ();
    }

    storage::info_popup_cb_ycp = info_popup_callback;

    return YCPVoid ();
}

YCPValue
StorageCallbacks::YesNoPopup (const YCPString & callback)
{
    string name_r = callback->value ();

    y2debug ("Registering callback %s", name_r.c_str ());
    string::size_type colonpos = name_r.find("::");

    if ( colonpos == string::npos )
    {
	ycp2error ("Specify namespace and the fuction name for a callback");
	return YCPVoid ();
    }

    string module = name_r.substr ( 0, colonpos );
    string name = name_r.substr ( colonpos + 2 );

    Y2Component *c = Y2ComponentBroker::getNamespaceComponent (module.c_str ());
    if (c == NULL)
    {
	ycp2error ("No component can provide namespace %s for a callback of %s",
		   module.c_str (), name.c_str ());
	return YCPVoid ();
    }

    Y2Namespace *ns = c->import (module.c_str ());
    if (ns == NULL)
    {
	y2error ("No namespace %s for a callback of %s", module.c_str (),
		 name.c_str ());
	return YCPVoid ();
    }

    yesno_popup = ns->createFunctionCall (name, Type::Unspec);
    if (yesno_popup == NULL)
    {
	ycp2error ("Cannot find function %s in module %s as a callback",
		   name.c_str(), module.c_str () );
	return YCPVoid ();
    }

    storage::yesno_popup_cb_ycp = yesno_popup_callback;

    return YCPVoid ();
}


YCPValue
StorageCallbacks::CommitErrorPopup(const YCPString& callback)
{
    string name_r = callback->value();
    
    y2debug("Registering callback %s", name_r.c_str());
    string::size_type colonpos = name_r.find("::");
    
    if (colonpos == string::npos)
    {
	ycp2error ("Specify namespace and the fuction name for a callback");
	return YCPVoid ();
    }
    
    string module = name_r.substr(0, colonpos);
    string name = name_r.substr(colonpos + 2);
    
    Y2Component* c = Y2ComponentBroker::getNamespaceComponent(module.c_str());
    if (c == NULL)
    {
	ycp2error("No component can provide namespace %s for a callback of %s",
		  module.c_str(), name.c_str());
	return YCPVoid();
    }
    
    Y2Namespace* ns = c->import(module.c_str());
    if (ns == NULL)
    {
	y2error("No namespace %s for a callback of %s", module.c_str(),
		name.c_str());
	return YCPVoid();
    }
    
    commit_error_popup = ns->createFunctionCall(name, Type::Unspec);
    if (commit_error_popup == NULL)
    {
	ycp2error("Cannot find function %s in module %s as a callback",
		  name.c_str(), module.c_str());
	return YCPVoid();
    }
    
    storage::commit_error_popup_cb_ycp = commit_error_popup_callback;
    
    return YCPVoid();
}


YCPValue
StorageCallbacks::PasswordPopup (const YCPString & callback)
{
    string name_r = callback->value ();

    y2debug ("Registering callback %s", name_r.c_str ());
    string::size_type colonpos = name_r.find("::");

    if ( colonpos == string::npos )
    {
	ycp2error ("Specify namespace and the fuction name for a callback");
	return YCPVoid ();
    }

    string module = name_r.substr ( 0, colonpos );
    string name = name_r.substr ( colonpos + 2 );

    Y2Component *c = Y2ComponentBroker::getNamespaceComponent (module.c_str ());
    if (c == NULL)
    {
	ycp2error ("No component can provide namespace %s for a callback of %s",
		   module.c_str (), name.c_str ());
	return YCPVoid ();
    }

    Y2Namespace *ns = c->import (module.c_str ());
    if (ns == NULL)
    {
	y2error ("No namespace %s for a callback of %s", module.c_str (),
		 name.c_str ());
	return YCPVoid ();
    }

    password_popup = ns->createFunctionCall (name, Type::Unspec);
    if (password_popup == NULL)
    {
	ycp2error ("Cannot find function %s in module %s as a callback",
		   name.c_str(), module.c_str () );
	return YCPVoid ();
    }

    storage::password_popup_cb_ycp = password_popup_callback;

    return YCPVoid ();
}

void
log_do( int level, const string& component, const char* file, int line, const char* func,
        const string& text)
    {
    y2_logger_function((loglevel_t)level, component, file, line, func, "%s", text.c_str());
    }

void StorageCallbacks::registerLogHandlers()
    {
    storage::setLogDoCallback(&log_do);
    storage::setLogQueryCallback(&should_be_logged);
    }
