export class FunUtils{
  static isNumberString(value: string): boolean {
    if (value === '') {
      return false;
    }
    const num = Number(value);
    return !isNaN(num) && isFinite(num);
  }

}