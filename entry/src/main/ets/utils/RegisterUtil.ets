import http from '@ohos.net.http';

interface UserData {
  id: number;
  account: number;
  password: string;
}

// 定义发送给后端的完整数据结构
interface RegisterRequest {
  account: number;
  password: string;
  avatarUrl: string;
  username: string; // 新增
  wakeWord: string; // 新增
}

export interface RegisterResult {
  success: boolean;
  msg: string;
}

export class RegisterUtil {
  /**
   * 注册方法（已修复参数数量）
   */
  static async register(
    account: number,
    password: string,
    avatarUrl: string,
    username: string,
    wakeWord: string
  ): Promise<RegisterResult> { // 这里显式声明返回类型，解决 implicit return type 警告

    if (!account || !password) {
      return { success: false, msg: '账号或密码不能为空' };
    }

    const httpRequest = http.createHttp();
    // 请确保 localhost 地址正确，模拟器通常用 127.0.0.1 或电脑局域网IP
    const localhost = AppStorage.get<string>('localhost') || 'localhost';
    const baseUrl = `http://${localhost}:8080/api/accounts`;

    try {
      // 1. 查询账号是否存在
      const queryResponse = await httpRequest.request(`${baseUrl}/account/${account}`, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (queryResponse.responseCode === 200) {
        const dataText: string = typeof queryResponse.result === 'string'
          ? queryResponse.result
          : JSON.stringify(queryResponse.result);

        // 简单的判空逻辑
        if (dataText && dataText !== '[]' && dataText !== 'null') {
          return { success: false, msg: '账号已存在' };
        }
      }

      // 2. 注册新账号 (包含5个字段)
      const registerRequest: RegisterRequest = {
        account: account,
        password: password,
        avatarUrl: avatarUrl,
        username: username,
        wakeWord: wakeWord
      };

      const registerResponse = await httpRequest.request(baseUrl, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(registerRequest),
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (registerResponse.responseCode === 200) {
        // 假设后端返回 "1" 代表成功
        const text: string = typeof registerResponse.result === 'string'
          ? registerResponse.result
          : JSON.stringify(registerResponse.result);
        const resultNum: number = parseInt(text);

        if (resultNum === 1) {
          return { success: true, msg: '注册成功' };
        } else {
          return { success: false, msg: '注册失败' };
        }
      } else {
        return { success: false, msg: `HTTP错误: ${registerResponse.responseCode}` };
      }

    } catch (err) {
      console.error('注册请求异常:', err);
      return { success: false, msg: '网络错误或服务器异常' };
    } finally {
      httpRequest.destroy();
    }
  }
}