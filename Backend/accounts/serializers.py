
# 2. 회원가입용 Serializer
class SignUpSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True) # 비밀번호는 읽기 불가

    class Meta:
        model = User
        fields = ['username', 'password', 'nickname', "user_real_name", 'phone_number', 'gender']

    def create(self, validated_data):
        # UserManager의 create_user를 호출하여 비밀번호를 암호화함
        return User.objects.create_user(**validated_data)