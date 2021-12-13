# Template-CloudFormation

`Template-CloudFormation`は`AWS CloudFormation`を利用したInfrastructure as CodeのTemplateファイル群である。


# Requirement

ローカル環境よりSSH接続で動作確認済
- インスタンス: AWS EC2
- OS: Amazon Linux 2

Windowsローカル仮想環境で動作確認済
- WSL2 (Ubuntu20.04)

<br>

**`Windows`環境では`.sh`が実行出来ないので注意**

<br>


# Installation

1. AWSへアクセスし、CloudFormation実行用IAMユーザーを作成する。
    <br>
    ユーザーポリシーは下記を推奨する。
    <br>
    但しポリシー要件によってAdmin権限が許可されない場合は構築リソースによって最小権限とする事。
    ```
    # ユーザーポリシー
    arn:aws:iam::aws:policy/AdministratorAccess
    ```

<br>

2. `{作成したユーザー}`を選択し`認証情報`タブへ移動`アクセスキーの作成`を行う。
    <br>
    credentialの記載された`.csv`ファイルをダウンロードする。

<br>

3. `.aws`を作成する。
    ```Bash
    $ aws configure
    ```
    **上記を実行すると`AWS Access Key ID`等の入力を求められるが、次のステップでファイルを編集するので何も入力せずに進む。**

<br>

4. `.csv`内に記載されている`Access key ID`及び`Secret access key`を`\.aws\credentials`内に転記する。
    ```
    [default]
    aws_access_key_id = {Access key ID}
    aws_secret_access_key = {Secret access key}
    region = {任意のリージョン}

    [Template-dev]
    aws_access_key_id = {Access key ID}
    aws_secret_access_key = {Secret access key}
    region = ap-northeast-1

    # 任意に構築先を追加作成可能
    # 構築先AWSアカウント毎に設定を行う
    [{プロジェクト名}-{環境名}]
    aws_access_key_id = {Access key ID}
    aws_secret_access_key = {Secret access key}
    region = ap-northeast-1
    ```

<br>

5. `Bash`で各`.sh`に権限を付与する。
    ```Bash
    $ chmod +x ${ファイル名}
    ```

<br>


# Usage

1. `\Template\{リソース名}.yml`内の`構築対象リソース以外のコード`をコメントアウトまたは削除する。
    <br>
    <br>
    ### 例: `PublicSubnet2`をコメントアウトし`VPC`及び`PublicSubnet1`のみ構築する
    ```yml
    Resources:
    # VPC作成
    VPC:
        Type: AWS::EC2::VPC
        Properties:
        CidrBlock: !Ref VPCCidrBlock
        EnableDnsSupport: true
        EnableDnsHostnames: true
        InstanceTenancy: default
        Tags:
            - Key: Name
            Value: !Sub
            - ${SystemName}-${EnvType}-vpc
            - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
            - Key: SystemName
            Value: !Ref SystemName
            - Key: EnvType
            Value: !Ref EnvType

    # Publicサブネット作成
    PublicSubnet1:
        Type: AWS::EC2::Subnet
        Properties:
        VpcId: !Ref VPC
        CidrBlock: !Ref PublicSubnetCidrBlock1
        AvailabilityZone: !FindInMap [AzMap, !Ref AWS::Region, 1st]
        MapPublicIpOnLaunch: true
        Tags:
            - Key: Name
            Value: !Sub
            - ${SystemName}-${EnvType}-public-subnet1
            - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
            - Key: SystemName
            Value: !Ref SystemName
            - Key: EnvType
            Value: !Ref EnvType
    # PublicSubnet2:
    #   Type: AWS::EC2::Subnet
    #   Properties:
    #     VpcId: !Ref VPC
    #     CidrBlock: !Ref PublicSubnetCidrBlock2
    #     AvailabilityZone: !FindInMap [AzMap, !Ref AWS::Region, 2nd]
    #     MapPublicIpOnLaunch: true
    #     Tags:
    #       - Key: Name
    #         Value: !Sub
    #         - ${SystemName}-${EnvType}-public-subnet2
    #         - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
    #       - Key: SystemName
    #         Value: !Ref SystemName
    #       - Key: EnvType
    #         Value: !Ref EnvType
    ```
    ### ソースコード下方に記載されている`Outputs`もコメントアウトまたは削除する。
    ```yml
    Outputs:
    VPC:
        Value: !Ref VPC
        Export:
        Name: !Sub
            - ${SystemName}-${EnvType}-vpc
            - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
    PublicSubnet1:
        Value: !Ref PublicSubnet1
        Export:
        Name: !Sub
            - ${SystemName}-${EnvType}-public-subnet1
            - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
    # PublicSubnet2:
    #   Value: !Ref PublicSubnet2
    #   Export:
    #     Name: !Sub
    #       - ${SystemName}-${EnvType}-public-subnet2
    #       - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
    ```

<br>

2. `\Template\{環境名}-parameters.json`内に各パラメータを設定する。
    <br>
    <br>
    ### 例:
    ```json
    {
        "Parameters": [
            {
                "ParameterKey": "SystemName",
                "ParameterValue": "Template"
            },
            {
                "ParameterKey": "EnvType",
                "ParameterValue": "dev"
            },
            {
                "ParameterKey": "VPCCidrBlock",
                "ParameterValue": "10.0.0.0/16"
            },
            {
                "ParameterKey": "PublicSubnetCidrBlock1",
                "ParameterValue": "10.0.1.0/24"
            },
            {
                "ParameterKey": "PublicSubnetCidrBlock2",
                "ParameterValue": "10.0.2.0/24"
            },
            {
                "ParameterKey": "PrivateSubnetCidrBlock1",
                "ParameterValue": "10.0.11.0/24"
            },
            {
                "ParameterKey": "PrivateSubnetCidrBlock2",
                "ParameterValue": "10.0.12.0/24"
            }
        ]
    }
    ```

<br>

3. `create_stacks.sh` (構築用)の設定を行う。
    <br>
    <br>
    ### 例:
    ```sh
    # SYSTEM_NAMEは{環境名}-parameters.jsonで設定した"SystemName"と一致させる必要がある。
    SYSTEM_NAME=Template


    #####################################
    # 共通
    #####################################
    # 構築対象リソースのコメントアウトを外す
    # また構築対象リソースは複数選択可能である。
    # 依存関係に注意する事 (例:sgを構築するにはnetworkを先に構築しなければならない)
    create_stack network

    ```
    <br>
    <br>

    `create_change_sets.sh` (更新用)
    <br>
    `delete_stacks.sh` (削除用)
    <br>
    <br>
    #### 上記についても`create_stacks.sh`と同様に設定を行う。
    #### **`create_stacks.sh`同様、依存関係に注意して操作する事。**

<br>

4. `Bash`で下記コマンドを実行する。
    ```Bash
    # 構築
    $ ./create_stacks.sh ${環境名}

    # 更新
    $ ./create_change_sets.sh ${環境名}

    # 削除
    $ ./delete_stacks.sh ${環境名}
    ```

<br>

5. `AWS CloudFormation`へアクセスしリソースが構築されているか確認を行う。

<br>
<br>

## CodeCommit リポジトリ追加手順

<br>

1. `code-commit.yml`内の`CodeCommitRepository テンプレート`をコメントアウト解除、コピペし、リソース名を
    <br>
    `CodeCommitRepository{NUMBERING}`と設定する。
    <br>
    `RepositoryName`, `RepositoryDescription`をそれぞれ任意の名称に設定する。
    <br>
    `Tags`の`{NUMBERING}`についても設定する。

    ```yml
    Resources:

    # 追加Repositoryは既存Repository下部へ追加推奨

    # CodeCommitRepository テンプレート
    # ここからコピペ
    CodeCommitRepository # {NUMBERING}:
        Type: AWS::CodeCommit::Repository
        Properties:
        RepositoryName: # {任意のRepositoryName}
        RepositoryDescription: # {任意のRepositoryDescription}
        Tags:
            - Key: Name
            Value: !Sub
                - ${SystemName}-${EnvType}-code-commit-repo- # {NUMBERING}
                - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
            - Key: SystemName
            Value: !Ref SystemName
            - Key: EnvType
            Value: !Ref EnvType
    # ここまでコピペ
    ```

<br>

2. `CodeCommitRepositoryName テンプレート`及び`CodeCommitRepositoryURL テンプレート`
    <br>
    をコメントアウト解除、コピペし、リソース名を
    <br>
    `CodeCommitRepositoryName{NUMBERING}`、`CodeCommitRepositoryURL{NUMBERING}`
    <br>
    とそれぞれ設定する。
    <br>
    また`Value`及び`Name`についても`{NUMBERING}`を設定変更する。

    ```yml
    Outputs:

    # 追加Outputsは既存Outputsリソース下部へ追加推奨

    # CodeCommitRepositoryName テンプレート
    # ここからコピペ
    CodeCommitRepositoryName # {NUMBERING}:
        Value: !GetAtt CodeCommitRepository # {NUMBERING}.Name
        Export:
        Name: !Sub
            - ${SystemName}-${EnvType}-code-commit-repo-name- # {NUMBERING}
            - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
    # CodeCommitRepositoryURL テンプレート
    # ↑コメント削除
    CodeCommitRepositoryURL # {NUMBERING}:
        Value: !GetAtt CodeCommitRepository # {NUMBERING}.CloneUrlHttp
        Export:
        Name: !Sub
            - ${SystemName}-${EnvType}-code-commit-repo-url- # {NUMBERING}
            - {SystemName: !Ref SystemName, EnvType: !Ref EnvType}
    # ここまでコピペ
    ```

<br>

3. `code-commit`の`create_change_sets.sh`を実行する。


# Note

- 現在対応している環境名は `dev`(開発用), `stg`(検証用), `prod`(本番用) のみである。
- `create_change_sets.sh` (更新用) についてはコマンド実行後、変更セットの実行が必要である。
    <br>
    参考URL:
    <br>
    https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/using-cfn-updating-stacks-changesets-execute.html
- 2021-11-25現在`import_acm.sh`は未実装

<br>


# Author
- 作成者 : NaoyaOgura