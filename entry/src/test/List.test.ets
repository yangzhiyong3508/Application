import localUnitTest from './LocalUnit.test';
import gamepadControlMapperTest from './GamepadControlMapper.test';
import eventReminderLogicTest from './EventReminderLogic.test';
import servoCalibrationLogicTest from './ServoCalibrationLogic.test';

export default function testsuite() {
  localUnitTest();
  gamepadControlMapperTest();
  eventReminderLogicTest();
  servoCalibrationLogicTest();
}
