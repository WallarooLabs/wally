use "wallaroo"

primitive MachidaStartupHelp
  fun apply() =>
    @printf[I32](
      """

      -------------------------------------------------------------------------
      Machida takes the following parameters:
      -------------------------------------------------------------------------
        --application-module [Specify the Machida application module]
      """.cstring()
    )
    StartupHelp()
