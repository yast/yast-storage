// -*- c++ -*-

#ifndef Y2CCFdiskAgent_h
#define Y2CCFdiskAgent_h

#include "Y2.h"

class Y2CCFdiskAgent : public Y2ComponentCreator
{
public:
    /**
     * Creates a new Y2CCFdiskAgent object.
     */
    Y2CCFdiskAgent();
    
    /**
     * Returns true: The FdiskAgent is a server component.
     */
    bool isServerCreator() const;
    
    /**
     * Creates a new @ref Y2SCRComponent, if name is "ag_fdisk".
     */
    Y2Component *create(const char *name) const;
};

#endif
