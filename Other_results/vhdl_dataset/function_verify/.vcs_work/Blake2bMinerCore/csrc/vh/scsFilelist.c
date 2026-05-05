#include "stdio.h"
#ifdef __cplusplus
extern "C" {
#endif
extern char at_least_one_object_file;
extern void *kernel_scs_file_ht_new(const void *, int);
extern int kernel_scs_file_ht_get(void *, const char *, int *);
extern int  strcmp(const char*, const char*);
  typedef struct {
    char* dFileName;
  } lPkgFileInfoStruct;

  typedef struct {
    char* dFileName;
    char* dRealFileName;
    long dFileOffset;
    unsigned long dFileSize;
    int dFileModTime;
    unsigned int simFlag;
  } lFileInfoStruct;

static int lNumOfScsFiles;
  static lFileInfoStruct lFInfoArr[] = {
  {"synopsys_sim.setup_0", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 3009, 4104, 1464145427, 0},
  {"./64/BLAKE2BMINERCORE_TARGET_TB.sim", "", 0, 3009, 0, 1},
  {"./64/PKGBLAKE2B.sim", "", 7113, 19992, 0, 1},
  {"./64/DUMMY_MHDL_CFG_BLAKE2BMINERCORE_TARGET_TB.sim", "", 27105, 12906, 0, 0},
  {"./64/BLAKE2BMINERCORE_TARGET_TB__TB.sim", "", 40011, 18942, 0, 1},
  {"./64/BLAKE2BMINERCORE.sim", "", 58953, 5871, 0, 1},
  {"./64/QUADG.sim", "", 64824, 6210, 0, 1},
  {"./64/BLAKE2BMINERCORE__RTL.sim", "", 71034, 69247, 0, 1},
  {"./64/MIXG_FLOPPIPE_4.sim", "", 140281, 6053, 0, 1},
  {"./64/QUADG__RTL.sim", "", 146334, 9951, 0, 1},
  {"./64/MIXG_FLOPPIPE_4__RTL.sim", "", 156285, 18944, 0, 1},
  {"./64/QUADG.mra", "", 175229, 4, 0, 0},
  {"./64/QUADG.mra", "", 175233, 4, 0, 0},
  {"./64/MIXG_FLOPPIPE_4.mra", "", 175237, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 14;
  lNumOfPkgSimFiles = 0;
  if (!ht)
  {
    ht  = kernel_scs_file_ht_new(lFInfoArr, lNumOfScsFiles);
  }
  if (ht && (kernel_scs_file_ht_get(ht, xFileName, &i) == 0))
  { /* found it! The indicator 'i' was set properly. */
    if (xRealFileName)
        *xRealFileName = lFInfoArr[i].dRealFileName;
    *xFileSizePtr = lFInfoArr[i].dFileSize;
    *xFileOffsetPtr = lFInfoArr[i].dFileOffset;
    return 0;
  }
  return 1;
}
int getNextSimFile(char **fn, long *offset)
{
  static int cur;
  for ( ; cur < lNumOfScsFiles; ) {
    if (!lFInfoArr[cur].simFlag) {
      cur++;
      continue;
    }
    *fn = lFInfoArr[cur].dFileName;
    *offset = lFInfoArr[cur].dFileOffset;
    cur++;
    return 1;
  }
  return 0;
}

#ifdef __cplusplus
}
#endif
