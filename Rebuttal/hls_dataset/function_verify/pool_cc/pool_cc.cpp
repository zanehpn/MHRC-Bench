#include <cfloat>
#include "hls_stream.h"

#define IMG_ROWS 4
#define IMG_COLS 4
#define POOL_ROWS 2
#define POOL_COLS 2
#define FILTERS 4

void max_pooling(hls::stream<float> & conv_to_pool_stream, hls::stream<float> & pool_to_flat_stream)
{
<TARGET>

  pool_for_rows:
  for (int r = 0; r < IMG_ROWS; r += POOL_ROWS)
  {
    pool_for_cols:
    for(int c = 0; c < IMG_COLS; c += POOL_COLS)
    {
      pool = FLT_MIN;

      pool_for_pr:
      for (int pr = 0; pr < POOL_ROWS; ++pr)
        pool_for_pc:
        for (int pc = 0; pc < POOL_COLS; ++pc)
        {
          float value = conv_to_pool_stream.read();
          if(value > pool)
            pool = value;
        }

      pool_to_flat_stream.write(pool);
    }
  }
}
