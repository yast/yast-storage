// -*- c++ -*-

#ifndef Y2CCMdAgent_h
#define Y2CCMdAgent_h

#include "Y2.h"

class Y2CCMdAgent : public Y2ComponentCreator
{
public:
    /**
     * Creates a new Y2CCMdAgent object.
     */
    Y2CCMdAgent();
    
    /**
     * Returns true: The MdAgent is a server component.
     */
    bool isServerCreator() const;
    
    /**
     * Creates a new @ref Y2SCRComponent, if name is "ag_md".
     */
    Y2Component *create(const char *name) const;
};

#endif
