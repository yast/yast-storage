// -*- c++ -*-
// Maintainer: fehr@suse.de

#ifndef FdiskAgent_h
#define FdiskAgent_h

#include <scr/SCRAgent.h>
#include <Y2.h>

/**
 * @short SCR Agent for access to fdisk
 */

class FdiskAgent : public SCRAgent 
{
public:
  FdiskAgent();

  ~FdiskAgent();

  /**
   * Reads data.
   * @param path Specifies what part of the subtree should
   * be read. The path is specified _relatively_ to Root()!
   */
  YCPValue Read( const YCPPath& path, const YCPValue& arg = YCPNull(),
                 const YCPValue& opt = YCPNull() );

  /**
   * Writes data.
   */
  YCPBoolean Write(const YCPPath& path, const YCPValue& value, const YCPValue& arg = YCPNull());

  /**
   * Get a list of all subtrees.
   */
  YCPList Dir(const YCPPath& path);
};


#endif // FdiskAgent_h
