#ifndef Y2CCParted_h
#define Y2CCParted_h

#include <Y2.h>
#include "Y2PartedComponent.h"

class Y2CCParted : public Y2ComponentCreator
{
public:
   // Create a parted component creator and register it
   Y2CCParted() : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
      {}

   // The parted component is a client
   bool isServerCreator() const { return false; }

   // Create a new parted component if name is our name
   Y2Component *create(const char *name) const
      {
	 if (strcmp(name, Y2PartedComponent::component_name().c_str()) == 0)
	    return new Y2PartedComponent();
	 else
	    return 0;
      }
};

#endif // Y2CCParted_h
