

#include "Y2MdAgentComponent.h"
#include <scr/SCRInterpreter.h>
#include "MdAgent.h"


Y2MdComponent::Y2MdComponent()
    : interpreter(0),
      agent(0)
{
}


Y2MdComponent::~Y2MdComponent()
{
    if (interpreter) {
	delete agent;
	delete interpreter;
    }
}


bool Y2MdComponent::isServer() const
{
    return true;
}


string Y2MdComponent::name() const
{
    return "ag_md";
}


YCPValue Y2MdComponent::evaluate(const YCPValue& value)
{
    if (!interpreter) {
	agent = new MdAgent();
	interpreter = new SCRInterpreter(agent);
    }
    
    return interpreter->evaluate(value);
}
