
#include <string.h>

#include "Y2CCMdAgent.h"
#include "Y2MdAgentComponent.h"

Y2CCMdAgent::Y2CCMdAgent()
  : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
{
}

bool Y2CCMdAgent::isServerCreator() const
{
  return true;
}

Y2Component *Y2CCMdAgent::create(const char *name) const
{
  if (!strcmp(name, "ag_md"))
      return new Y2MdComponent();
  else return 0;
}

Y2CCMdAgent g_y2ccag_md;
