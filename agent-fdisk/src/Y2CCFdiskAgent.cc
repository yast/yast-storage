
#include <string.h>

#include "Y2CCFdiskAgent.h"
#include "Y2FdiskAgentComponent.h"

Y2CCFdiskAgent::Y2CCFdiskAgent()
  : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
{
}

bool Y2CCFdiskAgent::isServerCreator() const
{
  return true;
}

Y2Component *Y2CCFdiskAgent::create(const char *name) const
{
  if (!strcmp(name, "ag_fdisk"))
      return new Y2FdiskComponent();
  else return 0;
}

Y2CCFdiskAgent g_y2ccag_fdisk;
