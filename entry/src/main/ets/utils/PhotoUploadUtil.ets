import {
  CosXmlBaseService,
  CosXmlServiceConfig,
  QCloudCredential,
  PutObjectRequest,
  CosError,
  TransferConfig,
  UploadTask,
  CredentialCallBack
} from '@tencentcloud/cos';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

export class CosHelper {
  private static instance: CosHelper;
  private bucket: string = "edog-avatar-1361772203";
  private region: string = "ap-nanjing";
  private context: common.Context | null = null;
  private isInitialized: boolean = false;

  private constructor() {}

  /**
   * 获取单例实例
   */
  public static getInstance(): CosHelper {
    if (!CosHelper.instance) {
      CosHelper.instance = new CosHelper();
    }
    return CosHelper.instance;
  }

  /**
   * 初始化 COS 服务 (使用永久密钥)
   * @param context 应用上下文
   * @param region 地域，例如 "ap-guangzhou"
   * @param bucket 存储桶名称，例如 "example bucket-1250000000"
   * @param secretId 腾讯云 SecretId
   * @param secretKey 腾讯云 SecretKey
   */
  public init(context: common.Context, region: string, bucket: string, secretId: string, secretKey: string) {
    this.context = context;
    this.bucket = bucket;
    this.region = region;

    // 1. 配置服务 config
    let cosXmlServiceConfig = new CosXmlServiceConfig(region);

    // 2. 配置永久密钥回调
    let credentialCallback: CredentialCallBack = () => {
      return new Promise((resolve) => {
        let credential = new QCloudCredential();
        // 设置传入的密钥
        credential.secretID = secretId;
        credential.secretKey = secretKey;
        // 永久密钥不需要 token
        resolve(credential);
      });
    };

    // 3. 初始化默认 Service
    CosXmlBaseService.initDefaultService(
      context.getApplicationContext(),
      cosXmlServiceConfig,
      credentialCallback
    );

    this.isInitialized = true;
    console.info("COS Service initialized with permanent credentials.");
  }

  /**
   * 上传单个文件
   * @param uri 图片的 uri
   * @param objectKey (可选) 在 COS 上的路径及文件名
   * @returns Promise<string> 返回上传后的访问 URL
   */
  public async uploadFile(uri: string, objectKey?: string): Promise<string> {
    if (!this.isInitialized || !this.context) {
      return Promise.reject("COS Service not initialized. Please call init() first.");
    }

    // 1. 将 URI 转换为沙箱中的物理路径
    let srcPath: string;
    try {
      srcPath = this.copyUriToCache(uri);
    } catch (e) {
      return Promise.reject(`File processing failed: ${JSON.stringify(e)}`);
    }

    // 2. 确定对象键 (文件名)
    if (!objectKey) {
      const ext = "jpg";
      const fileName = `${new Date().getTime()}.${ext}`;
      objectKey = `uploads/${fileName}`;
    }

    // 3. 构建上传请求
    let transferConfig = new TransferConfig();
    let putRequest = new PutObjectRequest(this.bucket, objectKey, srcPath);

    return new Promise((resolve, reject) => {
      // 4. 获取默认服务并开始上传
      let task: UploadTask = CosXmlBaseService.default().upload(putRequest, undefined, transferConfig);

      // 设置结果监听
      task.onResult = {
        onSuccess: (_request) => {
          const location = `https://${this.bucket}.cos.${this.region}.myqcloud.com/${objectKey}`;
          resolve(location);
        },
        // ---------------------------------------------------------
        // 修改点：修复 Property 'code' does not exist 错误
        // ---------------------------------------------------------
        onFail: (_request, error: CosError) => {
          // 打印完整错误对象以便调试
          console.error("COS Upload Fail Full Error:", JSON.stringify(error));

          // 如果需要获取具体的错误码，有时它在 message 里，或者需要断言为 any (不推荐但可行)
          // 这里使用 message 属性，它是标准的 Error 属性
          const errorMsg = `Upload failed: ${error.message}`;
          reject(errorMsg);
        }
      };

      // 设置进度监听
      task.onProgress = (progress) => {
        console.info(`Upload Progress: ${progress.complete} / ${progress.target}`);
      };

      // 开始任务
      task.start();
    });
  }

  /**
   * 辅助方法：将 Picker 返回的 URI 拷贝到应用缓存目录
   */
  private copyUriToCache(uri: string): string {
    if (!this.context) throw new Error("Context is null");

    let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const timestamp = new Date().getTime();
    const targetFileName = `tmp_${timestamp}.jpg`;
    const targetPath = `${this.context.cacheDir}/${targetFileName}`;

    fs.copyFileSync(file.fd, targetPath);
    fs.closeSync(file);

    return targetPath;
  }
}