import localUnitTest from './LocalUnit.test';
import gamepadControlMapperTest from './GamepadControlMapper.test';

export default function testsuite() {
  localUnitTest();
  gamepadControlMapperTest();
}
