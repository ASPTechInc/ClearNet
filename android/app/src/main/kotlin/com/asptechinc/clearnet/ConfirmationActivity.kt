package com.asptechinc.clearnet

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import java.util.Random

/**
 * ConfirmationActivity requires the user to type three long, nonsensical sentences
 * exactly as shown to proceed with disabling blocking.
 */
class ConfirmationActivity : Activity() {

    private lateinit var tvStep: TextView
    private lateinit var tvTarget: TextView
    private lateinit var etInput: EditText
    private lateinit var btnAction: Button
    private lateinit var btnCancel: Button

    private val random = Random()
    private val sentences = mutableListOf<String>()
    private val userInputs = mutableListOf<String>()
    private var currentStep = 0

    // A pool of complex words to make typing difficult
    private val wordPool = listOf(
        "persistence", "extraordinary", "conundrum", "labyrinth", "ephemeral",
        "melancholy", "serendipity", "quintessential", "eloquence", "nefarious",
        "obfuscate", "pragmatic", "resilient", "ubiquitous", "vivacious",
        "whimsical", "zealous", "aberration", "benevolent", "capricious",
        "deference", "enervate", "garrulous", "haughty", "impetuous"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_confirmation)

        tvStep = findViewById(R.id.tv_step)
        tvTarget = findViewById(R.id.tv_target_sentence)
        etInput = findViewById(R.id.et_input)
        btnAction = findViewById(R.id.btn_action)
        btnCancel = findViewById(R.id.btn_cancel)

        generateSentences()
        updateUI()

        btnAction.setOnClickListener {
            handleAction()
        }

        btnCancel.setOnClickListener {
            setResult(RESULT_CANCELED)
            finish()
        }
    }

    private fun generateSentences() {
        sentences.clear()
        userInputs.clear()
        currentStep = 0
        repeat(3) {
            // Generating a sentence of 12-15 words
            sentences.add(generateRandomSentence(12 + random.nextInt(4)))
        }
    }

    private fun generateRandomSentence(length: Int): String {
        val sb = StringBuilder()
        for (i in 0 until length) {
            val word = wordPool[random.nextInt(wordPool.size)]
            sb.append(word)
            if (i < length - 1) sb.append(" ")
        }
        return sb.toString()
    }

    private fun updateUI() {
        tvStep.text = "Step ${currentStep + 1} of 3"
        tvTarget.text = sentences[currentStep]
        etInput.text.clear()
        
        if (currentStep == 2) {
            btnAction.text = "Submit"
        } else {
            btnAction.text = "Next"
        }
    }

    private fun handleAction() {
        val input = etInput.text.toString().trim()
        if (input.isEmpty()) {
            Toast.makeText(this, "Please type the sentence", Toast.LENGTH_SHORT).show()
            return
        }

        userInputs.add(input)

        if (currentStep < 2) {
            currentStep++
            updateUI()
        } else {
            validateAll()
        }
    }

    /**
     * Validates all three sentences at the end. If any is incorrect, the user
     * must start over with a completely new set of sentences.
     */
    private fun validateAll() {
        var allCorrect = true
        for (i in 0 until 3) {
            if (userInputs[i] != sentences[i]) {
                allCorrect = false
                break
            }
        }

        if (allCorrect) {
            setResult(RESULT_OK)
            finish()
        } else {
            Toast.makeText(this, "One or more sentences were incorrect! Starting over with new sentences.", Toast.LENGTH_LONG).show()
            generateSentences()
            updateUI()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Disable back button to prevent accidental or intentional dismissal
        Toast.makeText(this, "You must complete the task or click 'I give up'.", Toast.LENGTH_SHORT).show()
    }
}
