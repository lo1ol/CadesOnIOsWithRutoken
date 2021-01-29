#!/bin/sh
cd `dirname $0`
./cpverify CPROCSP.framework.tgz 0ED94A72317F2BD5F8540B5EC5368F139D21DC07FF589658480FF335986F48A0
test $? -eq 0 || exit 1
./cpverify CreateFile.tar.gz EAE2AEB64A60C59C4C872398C291CDAAFC9D2E930C266C8EC847AD212836C8B7
test $? -eq 0 || exit 1
./cpverify ios-arm7.ini 2BC9B645AD3C2DFD5868929BA4AFA830B013E2674A4839664444ED850DAD9A03
test $? -eq 0 || exit 1
./cpverify iStunnelSimple.tar.gz 3144E0D25506DA3829199F1EA29BBC10B850DD28583C001A704BE08D6BF3A62E
test $? -eq 0 || exit 1
printf "Everything is OK.\n"