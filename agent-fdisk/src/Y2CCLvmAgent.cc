
#include <string.h>

#include "Y2CCLvmAgent.h"
#include "Y2LvmAgentComponent.h"

Y2CCLvmAgent::Y2CCLvmAgent()
  : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
{
}

bool Y2CCLvmAgent::isServerCreator() const
{
  return true;
}

Y2Component *Y2CCLvmAgent::create(const char *name) const
{
  if (!strcmp(name, "ag_lvm"))
      return new Y2LvmComponent();
  else return 0;
}

Y2CCLvmAgent g_y2ccag_lvm;
