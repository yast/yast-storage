

/*
 *  Author: Arvin Schnell <arvin@suse.de>
 */


#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>
#include <scr/SCRInterpreter.h>

#include "MdAgent.h"


typedef Y2AgentComp <MdAgent> Y2MdAgentComp;

Y2CCAgentComp <Y2MdAgentComp> g_y2ccag_md ("ag_md");

