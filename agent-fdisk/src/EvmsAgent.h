// -*- c++ -*-
// Maintainer: fehr@suse.de

#ifndef EvmsAgent_h
#define EvmsAgent_h

#include <scr/SCRAgent.h>
#include <Y2.h>
#include <EvmsAccess.h>

/**
 * @short SCR Agent for access to evms
 */

class EvmsAgent : public SCRAgent 
{
public:
  EvmsAgent();

  ~EvmsAgent();

  /**
   * Reads data.
   * @param path Specifies what part of the subtree should
   * be read. The path is specified _relatively_ to Root()!
   */
  YCPValue Read( const YCPPath& path, const YCPValue& arg = YCPNull(),
		 const YCPValue& opt = YCPNull());

  /**
   * Writes data.
   */
  YCPBoolean Write( const YCPPath& path, const YCPValue& value, const YCPValue& arg = YCPNull());

  /**
   * Get a list of all subtrees.
   */
  YCPList Dir(const YCPPath& path);
protected:
  YCPMap CreateVolumeMap( const EvmsVolumeObject& Vol_Cv );
  YCPMap CreateContainerMap( const EvmsContainerObject& Vol_Cv );

  YCPMap   Err_C;
  EvmsAccess *Evms_pC;
};


#endif // EvmsAgent_h
