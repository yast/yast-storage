// -*- c++ -*-

/*
 *  Maintainer: Arvin Schnell <arvin@suse.de>
 */


#ifndef Y2CCMakefs_h
#define Y2CCMakefs_h


#include <Y2.h>

#include "Y2MakefsComponent.h"


class Y2CCMakefs : public Y2ComponentCreator
{
    
public:
    
    // Create a makefs component creator and register it
    Y2CCMakefs () :
	Y2ComponentCreator (Y2ComponentBroker::BUILTIN)
    {
    }
    
    // The makefs component is a client
    bool isServerCreator () const { return false; }
    
    // Create a new makefs component if name is our name
    Y2Component *create (const char *name) const
    {
	if (strcmp (name, Y2MakefsComponent::component_name ().c_str ()) == 0)
	    return new Y2MakefsComponent ();
	else
	    return 0;
    }
    
};


#endif // Y2CCMakefs_h
