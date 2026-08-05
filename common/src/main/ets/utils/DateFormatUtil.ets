/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


import { PlayConstants } from '../constants/player/PlayConstants';

const TAG = 'DateFormatUtil';


export interface DateFormat {
  YYYY_MM_DD: string,
  MM_DD: string,
  DATE_TIME: string,
  YYYY_MM_DD_CHINESE: string,
  MM_DD_CHINESE: string,
  DATE_TIME_CHINESE: string,
  HH_MM: string,
}

class DateFormatUtil {
  /**
   * Convert duration from seconds to time(HH:mm:ss).
   * @param The duration(second) to convert to time.
   * @return Time after conversion.
   */
  secondToTime(seconds: number): string {
    let time = `${PlayConstants.INITIAL_TIME_UNIT}:${PlayConstants.INITIAL_TIME_UNIT}`;
    if (seconds < 0) {
      return time;
    }
    let hourUnit = PlayConstants.TIME_UNIT * PlayConstants.TIME_UNIT;
    let hour = Math.floor(seconds / hourUnit);
    let minute = Math.floor((seconds - hour * hourUnit) / PlayConstants.TIME_UNIT);
    let second = seconds - hour * hourUnit - minute * PlayConstants.TIME_UNIT;
    if (hour > 0) {
      return `${this.padding(hour.toString())}:${this.padding(minute.toString())}:${this.padding(second.toString())}`;
    }
    if (minute > 0) {
      return `${this.padding(minute.toString())}:${this.padding(second.toString())}`;
    } else {
      return `${PlayConstants.INITIAL_TIME_UNIT}:${this.padding(second.toString())}`;
    }
  }

  /**
   * Zero padding, 2 bits.
   * @param num Number to be converted.
   * @return Result after zero padding.
   */
  padding(num: string): string {
    let length = PlayConstants.PADDING_LENGTH;
    for (let len = (num.toString()).length; len < length; len = num.length) {
      num = `${PlayConstants.PADDING_STR}${num}`;
    }
    return num;
  }
}

export default new DateFormatUtil();
