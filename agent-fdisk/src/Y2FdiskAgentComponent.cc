

#include "Y2FdiskAgentComponent.h"
#include <scr/SCRInterpreter.h>
#include "FdiskAgent.h"


Y2FdiskComponent::Y2FdiskComponent()
    : interpreter(0),
      agent(0)
{
}


Y2FdiskComponent::~Y2FdiskComponent()
{
    if (interpreter) {
	delete agent;
	delete interpreter;
    }
}


bool Y2FdiskComponent::isServer() const
{
    return true;
}


string Y2FdiskComponent::name() const
{
    return "ag_fdisk";
}


YCPValue Y2FdiskComponent::evaluate(const YCPValue& value)
{
    if (!interpreter) {
	agent = new FdiskAgent();
	interpreter = new SCRInterpreter(agent);
    }
    
    return interpreter->evaluate(value);
}
