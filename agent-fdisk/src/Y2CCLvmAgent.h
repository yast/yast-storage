// -*- c++ -*-

#ifndef Y2CCLvmAgent_h
#define Y2CCLvmAgent_h

#include "Y2.h"

class Y2CCLvmAgent : public Y2ComponentCreator
{
public:
    /**
     * Creates a new Y2CCLvmAgent object.
     */
    Y2CCLvmAgent();
    
    /**
     * Returns true: The LvmAgent is a server component.
     */
    bool isServerCreator() const;
    
    /**
     * Creates a new @ref Y2SCRComponent, if name is "ag_lvm".
     */
    Y2Component *create(const char *name) const;
};

#endif
