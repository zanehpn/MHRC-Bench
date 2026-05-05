scalaVersion := "2.13.12"

val chiselVersion = "6.0.0"

libraryDependencies ++= Seq(
  "org.chipsalliance" %% "chisel" % chiselVersion,
  "edu.berkeley.cs" %% "chiseltest" % "6.0.0" % "test",
  "org.scalatest" %% "scalatest" % "3.2.17" % "test",
)

addCompilerPlugin(("org.chipsalliance" % "chisel-plugin" % chiselVersion).cross(CrossVersion.full))

scalacOptions ++= Seq(
  "-deprecation",
  "-feature",
  "-language:reflectiveCalls",
)

resolvers ++= Resolver.sonatypeOssRepos("snapshots")
resolvers ++= Resolver.sonatypeOssRepos("releases")
