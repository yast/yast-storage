// -*- c++ -*-
// Maintainer: fehr@suse.de

#ifndef MdAgent_h
#define MdAgent_h

#include <scr/SCRAgent.h>
#include <Y2.h>
#include <MdAccess.h>

/**
 * @short SCR Agent for access to md
 */

class MdAgent : public SCRAgent 
{
public:
  MdAgent();

  ~MdAgent();

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
  YCPValue Write(const YCPPath& path, const YCPValue& value, const YCPValue& arg = YCPNull());

  /**
   * Get a list of all subtrees.
   */
  YCPValue Dir(const YCPPath& path);
protected:
  YCPMap CreateMdMap( const MdInfo& Md_Cv );
  MdAccess *Md_pC;
};


#endif // MdAgent_h
