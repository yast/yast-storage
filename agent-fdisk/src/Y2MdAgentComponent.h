// -*- c++ -*-

#ifndef Y2MdAgentComponent_h
#define Y2MdAgentComponent_h

#include "Y2.h"


class SCRInterpreter;
class MdAgent;


class Y2MdComponent : public Y2Component
{
    SCRInterpreter *interpreter;
    MdAgent *agent;
    
public:
    /**
     * Create a new Y2MdAgentComponent
     */    
    Y2MdComponent();
    
    /**
     * Cleans up
     */
    ~Y2MdComponent();
    
    /**
     * Returns true: The scr is a server component
     */
    bool isServer() const;
    
    /**
     * Returns "ag_mdagent": This is the name of the mdagent component
     */
    string name() const;
    
    /**
     * Evalutas a command to the scr
     */
    YCPValue evaluate(const YCPValue& command);
};


#endif
