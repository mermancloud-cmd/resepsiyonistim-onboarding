document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('onboarding-form');
    const steps = Array.from(document.querySelectorAll('.form-step'));
    const nextBtn = document.getElementById('next-btn');
    const prevBtn = document.getElementById('prev-btn');
    const submitBtn = document.getElementById('submit-btn');
    const progressBar = document.querySelector('.progress-bar');
    const onboardingContainer = document.getElementById('onboarding-container');
    const successContainer = document.getElementById('success-container');

    let currentStepIndex = 0;

    const updateTotalSteps = () => steps.length;
    const totalSteps = updateTotalSteps();

    const updateProgressBar = () => {
        const progress = ((currentStepIndex + 1) / totalSteps) * 100;
        progressBar.style.width = `${progress}%`;
    };

    const showStep = (stepIndex, direction = 'next') => {
        const currentStep = steps[currentStepIndex];
        const targetStep = steps[stepIndex];

        if (currentStep) {
            currentStep.classList.add('exiting', `slide-${direction}-exit`);
            targetStep.classList.add(`slide-${direction}-enter`);

            currentStep.addEventListener('transitionend', () => {
                currentStep.classList.remove('active', 'exiting', `slide-${direction}-exit`);
                targetStep.classList.remove(`slide-${direction}-enter`);
            }, { once: true });
        }
        
        targetStep.classList.add('active');
        currentStepIndex = stepIndex;

        updateProgressBar();
        updateNavigationButtons();
    };

    const updateNavigationButtons = () => {
        prevBtn.style.display = currentStepIndex > 0 ? 'inline-block' : 'none';
        nextBtn.style.display = currentStepIndex < totalSteps - 1 ? 'inline-block' : 'none';
        submitBtn.style.display = currentStepIndex === totalSteps - 1 ? 'inline-block' : 'none';
    };

    const validateStep = (stepIndex) => {
        const step = steps[stepIndex];
        const inputs = step.querySelectorAll('input[required], select[required], textarea[required]');
        let isValid = true;

        inputs.forEach(input => {
            const errorDiv = input.closest('.form-group').querySelector('.error-message');
            let errorMessage = '';

            if (input.type === 'checkbox' && !input.checked) {
                errorMessage = 'Bu alanı onaylamanız gerekmektedir.';
                isValid = false;
            } else if (input.type === 'email' && !/^\S+@\S+\.\S+$/.test(input.value.trim())) {
                errorMessage = 'Lütfen geçerli bir e-posta adresi girin.';
                isValid = false;
            } else if (input.value.trim() === '') {
                errorMessage = 'Bu alan zorunludur.';
                isValid = false;
            }

            if (errorMessage) {
                input.classList.add('invalid');
                errorDiv.textContent = errorMessage;
            } else {
                input.classList.remove('invalid');
                errorDiv.textContent = '';
            }
        });

        return isValid;
    };

    nextBtn.addEventListener('click', () => {
        if (validateStep(currentStepIndex)) {
            if (currentStepIndex < totalSteps - 1) {
                showStep(currentStepIndex + 1, 'next');
            }
        }
    });

    prevBtn.addEventListener('click', () => {
        if (currentStepIndex > 0) {
            showStep(currentStepIndex - 1, 'prev');
        }
    });

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        if (validateStep(currentStepIndex)) {
            submitBtn.textContent = 'Kaydediliyor...';
            submitBtn.disabled = true;

            const formData = new FormData(form);
            const data = Object.fromEntries(formData.entries());

            try {
                const response = await fetch('YOUR_WEBHOOK_URL', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data),
                });

                if (response.ok) {
                    onboardingContainer.style.display = 'none';
                    successContainer.style.display = 'block';
                } else {
                    // Handle server-side error
                    const errorData = await response.json();
                    alert(`Bir hata oluştu: ${errorData.message || 'Lütfen tekrar deneyin.'}`);
                    submitBtn.textContent = 'Kaydet ve Aktive Et';
                    submitBtn.disabled = false;
                }
            } catch (error) {
                // Handle network error
                alert('Ağ hatası oluştu. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.');
                submitBtn.textContent = 'Kaydet ve Aktive Et';
                submitBtn.disabled = false;
            }
        }
    });

    // Initial setup
    showStep(0);
});
