

/*
 *  Author: Arvin Schnell <arvin@suse.de>
 */


#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>
#include <scr/SCRInterpreter.h>

#include "LvmAgent.h"


typedef Y2AgentComp <LvmAgent> Y2LvmAgentComp;

Y2CCAgentComp <Y2LvmAgentComp> g_y2ccag_lvm ("ag_lvm");

