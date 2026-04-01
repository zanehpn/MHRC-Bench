package magmasi.components

case class MagmasiConfig(
    val DATA_TYPE: Int = 16,
    val NUM_PES  : Int = 4,
    val NUM_OUT: Int = 2,
    val rowsA: Int = 4,
    val colsA: Int = 4,
    val rowsB: Int = 4,
    val colsB: Int = 4
)
