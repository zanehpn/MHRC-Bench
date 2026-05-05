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
  {"synopsys_sim.setup_0", "./synopsys_sim.setup", 2615, 50, 1774611745, 0},
  {"synopsys_sim.setup_1", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2665, 4104, 1464145427, 0},
  {"./work/64/DELAYLINE_TARGET_TB.sim", "", 0, 2615, 0, 1},
  {"./work/64/DUMMY_MHDL_CFG_DELAYLINE_TARGET_TB.sim", "", 6769, 16677, 0, 0},
  {"./work/64/DELAYLINE_TARGET_TB__TB.sim", "", 23446, 12669, 0, 1},
  {"./UNISIM/64/VCOMPONENTS.sim", "", 36115, 47173, 0, 1},
  {"./work/64/DELAYLINE.sim", "", 83288, 5240, 0, 1},
  {"./work/64/RISINGEDGEDETECTOR.sim", "", 88528, 3452, 0, 1},
  {"./work/64/RISINGEDGEDETECTOR__RTL.sim", "", 91980, 6010, 0, 1},
  {"./work/64/DELAYLINE__RTL.sim", "", 97990, 25009, 0, 1},
  {"./UNISIM/64/CARRY4.sim", "", 122999, 4499, 0, 1},
  {"./UNISIM/64/CARRY4__BEHAVIORAL.sim", "", 127498, 11895, 0, 1},

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
