

#include "Y2LvmAgentComponent.h"
#include <scr/SCRInterpreter.h>
#include "LvmAgent.h"


Y2LvmComponent::Y2LvmComponent()
    : interpreter(0),
      agent(0)
{
}


Y2LvmComponent::~Y2LvmComponent()
{
    if (interpreter) {
	delete agent;
	delete interpreter;
    }
}


bool Y2LvmComponent::isServer() const
{
    return true;
}


string Y2LvmComponent::name() const
{
    return "ag_lvm";
}


YCPValue Y2LvmComponent::evaluate(const YCPValue& value)
{
    if (!interpreter) {
	agent = new LvmAgent();
	interpreter = new SCRInterpreter(agent);
    }
    
    return interpreter->evaluate(value);
}
