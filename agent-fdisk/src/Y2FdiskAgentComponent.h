// -*- c++ -*-

#ifndef Y2FdiskAgentComponent_h
#define Y2FdiskAgentComponent_h

#include "Y2.h"


class SCRInterpreter;
class FdiskAgent;


class Y2FdiskComponent : public Y2Component
{
    SCRInterpreter *interpreter;
    FdiskAgent *agent;
    
public:
    /**
     * Create a new Y2FdiskAgentComponent
     */    
    Y2FdiskComponent();
    
    /**
     * Cleans up
     */
    ~Y2FdiskComponent();
    
    /**
     * Returns true: The scr is a server component
     */
    bool isServer() const;
    
    /**
     * Returns "ag_fdiskagent": This is the name of the fdiskagent component
     */
    string name() const;
    
    /**
     * Evalutas a command to the scr
     */
    YCPValue evaluate(const YCPValue& command);
};


#endif
