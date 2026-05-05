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
  {"synopsys_sim.setup_0", "./synopsys_sim.setup", 2693, 50, 1774612477, 0},
  {"synopsys_sim.setup_1", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2743, 4104, 1464145427, 0},
  {"./work/64/ENCODER_TARGET_TB.sim", "", 0, 2693, 0, 1},
  {"./work/64/DUMMY_MHDL_CFG_ENCODER_TARGET_TB.sim", "", 6847, 20399, 0, 0},
  {"./work/64/ENCODER_TARGET_TB__TB.sim", "", 27246, 14409, 0, 1},
  {"./work/64/MYPKG__.sim", "", 41655, 13200, 0, 1},
  {"./work/64/MYPKG.sim", "", 54855, 7578, 0, 1},
  {"./UNISIM/64/VCOMPONENTS.sim", "", 62433, 47173, 0, 1},
  {"./work/64/ENCODER.sim", "", 109606, 6230, 0, 1},
  {"./work/64/ADDERTREELEGACY.sim", "", 115836, 6555, 0, 1},
  {"./work/64/ADDERTREELEGACY__RECURSIVE.sim", "", 122391, 22100, 0, 1},
  {"./work/64/ENCODER__RTL.sim", "", 144491, 23839, 0, 1},
  {"./UNISIM/64/LUT6.sim", "", 168330, 5506, 0, 1},
  {"./UNISIM/64/LUT6__BEHAVIORAL.sim", "", 173836, 8867, 0, 1},

  };
  static lPkgFileInfoStruct lPkgFileInfoArr[] = {
  {"./work/64/MYPKG__.sim"},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 14;
  lNumOfPkgSimFiles = 1;
  if (xCheckInPkgSimFiles)
  {
     for (j = 0; j < lNumOfPkgSimFiles; j++)
     {
       char* lFName;
       lFName = lPkgFileInfoArr[k].dFileName;
       if (strcmp(lFName, xFileName) == 0)
           return 0;
       k = (k + 1) % lNumOfPkgSimFiles;
     }
     return 1;
  }
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
