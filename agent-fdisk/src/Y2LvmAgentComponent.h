// -*- c++ -*-

#ifndef Y2LvmAgentComponent_h
#define Y2LvmAgentComponent_h

#include "Y2.h"


class SCRInterpreter;
class LvmAgent;


class Y2LvmComponent : public Y2Component
{
    SCRInterpreter *interpreter;
    LvmAgent *agent;
    
public:
    /**
     * Create a new Y2LvmAgentComponent
     */    
    Y2LvmComponent();
    
    /**
     * Cleans up
     */
    ~Y2LvmComponent();
    
    /**
     * Returns true: The scr is a server component
     */
    bool isServer() const;
    
    /**
     * Returns "ag_lvmagent": This is the name of the lvmagent component
     */
    string name() const;
    
    /**
     * Evalutas a command to the scr
     */
    YCPValue evaluate(const YCPValue& command);
};


#endif
