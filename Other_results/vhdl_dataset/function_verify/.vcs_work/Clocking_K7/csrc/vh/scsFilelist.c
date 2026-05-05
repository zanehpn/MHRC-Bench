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
  {"synopsys_sim.setup_0", "./synopsys_sim.setup", 2772, 50, 1774612601, 0},
  {"synopsys_sim.setup_1", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2822, 4104, 1464145427, 0},
  {"./work/64/CLOCKING_K7_ORIGINAL_TARGET_TB.sim", "", 0, 2772, 0, 1},
  {"./work/64/DUMMY_MHDL_CFG_CLOCKING_K7_ORIGINAL_TARGET_TB.sim", "", 6926, 48892, 0, 0},
  {"./work/64/CLOCKING_K7.sim", "", 55818, 4112, 0, 1},
  {"./work/64/CLOCKING_K7_ORIGINAL_TARGET_TB__TB.sim", "", 59930, 10185, 0, 1},
  {"./work/64/CLOCKING_K7__RTL.sim", "", 70115, 32996, 0, 1},
  {"./UNISIM/64/PLLE2_ADV.sim", "", 103111, 20592, 0, 1},
  {"./UNISIM/64/PLLE2_ADV__BEHAVIORAL.sim", "", 123703, 48613, 0, 1},
  {"./UNISIM/64/BUFG.sim", "", 172316, 3065, 0, 1},
  {"./UNISIM/64/BUFG__BEHAVIORAL.sim", "", 175381, 4319, 0, 1},
  {"./work/64/CLOCKING_K7.mra", "", 179700, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 12;
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
